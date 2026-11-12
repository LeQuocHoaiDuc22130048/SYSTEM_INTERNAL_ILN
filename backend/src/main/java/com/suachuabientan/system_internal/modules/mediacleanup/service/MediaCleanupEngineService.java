package com.suachuabientan.system_internal.modules.mediacleanup.service;

import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.mediacleanup.config.MediaCleanupProperties;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaAsset;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaCleanupJob;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupJobStatus;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupLogOutcome;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupTriggerType;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.MediaAssetStatus;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaAssetRepository;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaCleanupJobRepository;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import io.micrometer.core.instrument.MeterRegistry;
import lombok.Builder;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

@Slf4j
@Service
@RequiredArgsConstructor
public class MediaCleanupEngineService {

    private static final DateTimeFormatter JOB_CODE_FORMAT =
            DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss").withZone(ZoneOffset.UTC);

    private final MediaCleanupProperties properties;
    private final MediaCleanupBatchWorker batchWorker;
    private final MediaCleanupRecoveryService recoveryService;
    private final MediaAssetRepository mediaAssetRepository;
    private final MediaCleanupJobRepository mediaCleanupJobRepository;
    private final NotificationService notificationService;
    private final MeterRegistry meterRegistry;

    @Value("${app.instance-id:default-instance}")
    private String instanceId;

    @Getter
    @Builder
    public static class CleanupDashboardStats {
        private final boolean engineEnabled;
        private final String cronExpression;
        private final int batchSize;
        private final long activeMediaCount;
        private final long eligibleExpiredCandidates;
        private final long cleanupInProgressCount;
        private final long softDeletedMediaCount;
        private final long permanentlyFailedMediaCount;
        private final long totalFreedBytes;
    }

    /**
     * Thực thi chu trình Media Cleanup Engine hoàn chỉnh:
     * 1. Phục hồi các job/bản ghi bị kẹt từ lần chạy trước (nếu có).
     * 2. Khởi tạo bản ghi MediaCleanupJob.
     * 3. Lặp theo từng batch 100 bản ghi (ShedLock + PostgreSQL FOR UPDATE SKIP LOCKED).
     * 4. Xóa S3 trước -> Cập nhật PostgreSQL SOFT_DELETED sau -> Ghi Audit Log & Metrics.
     */
    public MediaCleanupJob executeCleanupJob(CleanupTriggerType triggerType) {
        long startNanos = System.nanoTime();

        // Bước 1: Phục hồi trạng thái bị kẹt trước khi chạy
        recoveryService.recoverStuckState();

        int batchSize = properties.getBatchSize() > 0 ? properties.getBatchSize() : 100;
        int maxBatches = properties.getMaxBatchesPerRun() > 0 ? properties.getMaxBatchesPerRun() : 100;

        String jobCode = "MCJ-" + JOB_CODE_FORMAT.format(Instant.now()) + "-"
                + UUID.randomUUID().toString().substring(0, 6).toUpperCase();

        MediaCleanupJob job = MediaCleanupJob.builder()
                .jobCode(jobCode)
                .triggerType(triggerType)
                .status(CleanupJobStatus.RUNNING)
                .instanceId(instanceId)
                .batchSize(batchSize)
                .startedAt(Instant.now())
                .lastHeartbeatAt(Instant.now())
                .build();
        job = mediaCleanupJobRepository.save(job);

        log.info("Media Cleanup Engine started: jobCode={}, trigger={}, batchSize={}, instance={}",
                jobCode, triggerType, batchSize, instanceId);

        int batchesRun = 0;
        int totalProcessed = 0;
        int deletedCount = 0;
        int failedCount = 0;
        int skippedCount = 0;
        int permanentFailureCount = 0;
        long freedBytes = 0L;

        try {
            while (batchesRun < maxBatches) {
                List<MediaAsset> claimedBatch = batchWorker.claimNextBatch(job.getId(), batchSize);
                if (claimedBatch.isEmpty()) {
                    break;
                }

                batchesRun++;
                for (MediaAsset media : claimedBatch) {
                    MediaCleanupBatchWorker.ItemProcessResult result =
                            batchWorker.processClaimedMedia(job.getId(), media);
                    totalProcessed++;

                    if (result.getOutcome() == CleanupLogOutcome.SUCCESS) {
                        deletedCount++;
                        freedBytes += result.getFreedBytes();
                    } else if (result.getOutcome() == CleanupLogOutcome.SKIPPED) {
                        skippedCount++;
                    } else {
                        failedCount++;
                        if (result.isPermanentlyFailed()) {
                            permanentFailureCount++;
                        }
                    }
                }

                // Cập nhật Heartbeat và tiến độ sau mỗi batch 100 records
                job.setTotalBatches(batchesRun);
                job.setTotalProcessed(totalProcessed);
                job.setDeletedCount(deletedCount);
                job.setFailedCount(failedCount);
                job.setSkippedCount(skippedCount);
                job.setFreedBytes(freedBytes);
                job.setLastHeartbeatAt(Instant.now());
                job = mediaCleanupJobRepository.save(job);
            }

            job.setFinishedAt(Instant.now());
            job.setLastHeartbeatAt(Instant.now());
            if (failedCount == 0) {
                job.setStatus(CleanupJobStatus.COMPLETED);
            } else if (deletedCount > 0 || skippedCount > 0) {
                job.setStatus(CleanupJobStatus.PARTIAL_FAILURE);
                job.setErrorSummary("Hoàn tất với " + failedCount + " bản ghi lỗi (sẽ tự động retry theo Exponential Backoff).");
            } else {
                job.setStatus(CleanupJobStatus.FAILED);
                job.setErrorSummary("Tất cả " + failedCount + " bản ghi trong phiên đều gặp lỗi khi xóa S3.");
            }
            job = mediaCleanupJobRepository.save(job);

            recordMetrics(deletedCount, failedCount, skippedCount, freedBytes, System.nanoTime() - startNanos);
            if (permanentFailureCount > 0) {
                notifyAdminsOnPermanentFailure(jobCode, permanentFailureCount);
            }

            log.info("Media Cleanup Engine finished: jobCode={}, status={}, batches={}, deleted={}, failed={}, skipped={}, freedBytes={}",
                    jobCode, job.getStatus(), batchesRun, deletedCount, failedCount, skippedCount, freedBytes);
            return job;

        } catch (Exception ex) {
            log.error("Media Cleanup Engine encountered unexpected fatal error in job {}: {}", jobCode, ex.getMessage(), ex);
            job.setStatus(CleanupJobStatus.FAILED);
            job.setFinishedAt(Instant.now());
            job.setLastHeartbeatAt(Instant.now());
            job.setErrorSummary("Lỗi hệ thống: " + ex.getMessage());
            return mediaCleanupJobRepository.save(job);
        }
    }

    /**
     * Cho phép Admin đặt lại (reset) một bản ghi FAILED_PERMANENT hoặc ACTIVE đang chờ backoff để thử lại ngay.
     */
    @Transactional
    public MediaAsset resetMediaForImmediateRetry(UUID mediaId) {
        MediaAsset asset = mediaAssetRepository.findById(mediaId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy bản ghi Media: " + mediaId));
        if (asset.getStatus() == MediaAssetStatus.SOFT_DELETED) {
            return asset;
        }
        asset.setStatus(MediaAssetStatus.ACTIVE);
        asset.setRetryCount(0);
        asset.setNextRetryAt(Instant.now());
        asset.setClaimedByJobId(null);
        asset.setClaimedAt(null);
        if (asset.getExpiresAt() == null || asset.getExpiresAt().isAfter(Instant.now())) {
            asset.setExpiresAt(Instant.now());
        }
        return mediaAssetRepository.save(asset);
    }

    @Transactional(readOnly = true)
    public CleanupDashboardStats getDashboardStats() {
        Instant now = Instant.now();
        return CleanupDashboardStats.builder()
                .engineEnabled(properties.isEnabled())
                .cronExpression(properties.getCron())
                .batchSize(properties.getBatchSize())
                .activeMediaCount(mediaAssetRepository.countByStatus(MediaAssetStatus.ACTIVE))
                .eligibleExpiredCandidates(mediaAssetRepository.countEligibleCleanupCandidates(now))
                .cleanupInProgressCount(mediaAssetRepository.countByStatus(MediaAssetStatus.CLEANUP_IN_PROGRESS))
                .softDeletedMediaCount(mediaAssetRepository.countByStatus(MediaAssetStatus.SOFT_DELETED))
                .permanentlyFailedMediaCount(mediaAssetRepository.countByStatus(MediaAssetStatus.FAILED_PERMANENT))
                .totalFreedBytes(mediaAssetRepository.sumTotalFreedBytes())
                .build();
    }

    private void recordMetrics(int deletedCount, int failedCount, int skippedCount, long freedBytes, long durationNanos) {
        try {
            meterRegistry.counter("media.cleanup.deleted.total").increment(deletedCount);
            meterRegistry.counter("media.cleanup.failed.total").increment(failedCount);
            meterRegistry.counter("media.cleanup.skipped.total").increment(skippedCount);
            meterRegistry.counter("media.cleanup.freed.bytes").increment(freedBytes);
            meterRegistry.timer("media.cleanup.job.duration").record(durationNanos, TimeUnit.NANOSECONDS);
        } catch (Exception ignored) {
            // Không làm gián đoạn luồng chính nếu registry chưa sẵn sàng trong test
        }
    }

    private void notifyAdminsOnPermanentFailure(String jobCode, int permanentFailureCount) {
        try {
            notificationService.sendToRoles(
                    List.of(UserRole.SUPER_ADMIN, UserRole.ADMIN),
                    NotificationType.MEDIA_CLEANUP_ALERT,
                    "Cảnh báo dọn dẹp Media S3",
                    "Phiên dọn dẹp " + jobCode + " có " + permanentFailureCount
                            + " tệp vượt quá số lần retry tối đa. Vui lòng kiểm tra nhật ký Media Cleanup.",
                    "MEDIA_CLEANUP",
                    jobCode,
                    true
            );
        } catch (Exception ex) {
            log.warn("Không thể gửi thông báo cảnh báo Media Cleanup: {}", ex.getMessage());
        }
    }
}

