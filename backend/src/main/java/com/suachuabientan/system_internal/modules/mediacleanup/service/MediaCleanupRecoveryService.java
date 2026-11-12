package com.suachuabientan.system_internal.modules.mediacleanup.service;

import com.suachuabientan.system_internal.modules.mediacleanup.config.MediaCleanupProperties;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaAsset;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaCleanupJob;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaCleanupLog;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupJobStatus;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupLogAction;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupLogOutcome;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.MediaAssetStatus;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaAssetRepository;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaCleanupJobRepository;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaCleanupLogRepository;
import lombok.Builder;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class MediaCleanupRecoveryService {

    private final MediaAssetRepository mediaAssetRepository;
    private final MediaCleanupJobRepository mediaCleanupJobRepository;
    private final MediaCleanupLogRepository mediaCleanupLogRepository;
    private final MediaCleanupProperties properties;

    @Getter
    @Builder
    public static class RecoverySummary {
        private final int recoveredJobs;
        private final int recoveredMediaAssets;
    }

    /**
     * Phục hồi các Job RUNNING và các bản ghi Media CLEANUP_IN_PROGRESS bị treo
     * khi Application restart hoặc instance bị crash giữa chừng.
     */
    @Transactional
    public RecoverySummary recoverStuckState() {
        Instant now = Instant.now();
        long timeoutMinutes = Math.max(1L, properties.getStuckTimeoutMinutes());
        Instant staleThreshold = now.minus(timeoutMinutes, ChronoUnit.MINUTES);

        // 1. Phục hồi các Job RUNNING quá hạn heartbeat
        List<MediaCleanupJob> stuckJobs = mediaCleanupJobRepository
                .findByStatusAndLastHeartbeatAtBefore(CleanupJobStatus.RUNNING, staleThreshold);
        for (MediaCleanupJob job : stuckJobs) {
            job.setStatus(CleanupJobStatus.INTERRUPTED_RECOVERED);
            job.setFinishedAt(now);
            job.setErrorSummary("Job bị gián đoạn (Application restart hoặc quá hạn heartbeat) và đã được hệ thống phục hồi tự động.");
        }
        if (!stuckJobs.isEmpty()) {
            mediaCleanupJobRepository.saveAll(stuckJobs);
            log.warn("Media Cleanup Recovery: Đã đánh dấu phục hồi {} job bị gián đoạn", stuckJobs.size());
        }

        // 2. Phục hồi các bản ghi Media bị kẹt ở trạng thái CLEANUP_IN_PROGRESS
        List<MediaAsset> stuckAssets = mediaAssetRepository
                .findByStatusAndClaimedAtBefore(MediaAssetStatus.CLEANUP_IN_PROGRESS, staleThreshold);
        for (MediaAsset asset : stuckAssets) {
            UUID previousJobId = asset.getClaimedByJobId();
            asset.setStatus(MediaAssetStatus.ACTIVE);
            asset.setClaimedByJobId(null);
            asset.setClaimedAt(null);

            if (previousJobId != null && mediaCleanupJobRepository.existsById(previousJobId)) {
                mediaCleanupLogRepository.save(MediaCleanupLog.builder()
                        .jobId(previousJobId)
                        .mediaId(asset.getId())
                        .bucketName(asset.getBucketName())
                        .objectKey(asset.getObjectKey())
                        .fileSize(asset.getFileSize())
                        .action(CleanupLogAction.RECOVERY_RESET)
                        .outcome(CleanupLogOutcome.SUCCESS)
                        .attemptNumber(asset.getRetryCount() + 1)
                        .durationMs(0L)
                        .errorMessage("Phục hồi bản ghi CLEANUP_IN_PROGRESS về ACTIVE sau khi Application restart")
                        .build());
            }
        }
        if (!stuckAssets.isEmpty()) {
            mediaAssetRepository.saveAll(stuckAssets);
            log.warn("Media Cleanup Recovery: Đã trả {} bản ghi CLEANUP_IN_PROGRESS về ACTIVE để tiếp tục xử lý", stuckAssets.size());
        }

        return RecoverySummary.builder()
                .recoveredJobs(stuckJobs.size())
                .recoveredMediaAssets(stuckAssets.size())
                .build();
    }
}

