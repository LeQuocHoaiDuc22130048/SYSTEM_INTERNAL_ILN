package com.suachuabientan.system_internal.modules.mediacleanup.service;

import com.suachuabientan.system_internal.modules.mediacleanup.config.MediaCleanupProperties;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaAsset;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaCleanupLog;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupLogAction;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupLogOutcome;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.MediaAssetStatus;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaAssetRepository;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaCleanupLogRepository;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaReferenceRepository;
import lombok.Builder;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

@Slf4j
@Service
@RequiredArgsConstructor
public class MediaCleanupBatchWorker {

    private final MediaAssetRepository mediaAssetRepository;
    private final MediaReferenceRepository mediaReferenceRepository;
    private final MediaCleanupLogRepository mediaCleanupLogRepository;
    private final ObjectStorageCleanupClient objectStorageCleanupClient;
    private final MediaCleanupProperties properties;
    private final TransactionTemplate transactionTemplate;

    @Getter
    @Builder
    public static class ItemProcessResult {
        private final CleanupLogOutcome outcome;
        private final boolean permanentlyFailed;
        private final long freedBytes;
    }

    /**
     * Khóa dòng (PostgreSQL Row Lock: FOR UPDATE SKIP LOCKED) và claim tối đa batchSize (100) bản ghi
     * trong một transaction ngắn để không giữ lock khi gọi mạng sang S3.
     */
    public List<MediaAsset> claimNextBatch(UUID jobId, int batchSize) {
        return transactionTemplate.execute(status -> {
            Instant now = Instant.now();
            List<MediaAsset> candidates = mediaAssetRepository.findCandidatesForCleanupWithRowLock(now, batchSize);
            if (candidates.isEmpty()) {
                return List.of();
            }
            for (MediaAsset candidate : candidates) {
                candidate.setStatus(MediaAssetStatus.CLEANUP_IN_PROGRESS);
                candidate.setClaimedByJobId(jobId);
                candidate.setClaimedAt(now);
            }
            return mediaAssetRepository.saveAll(candidates);
        });
    }

    /**
     * Xử lý từng bản ghi Media theo đúng thứ tự thiết kế:
     * 1. Kiểm tra lại reference lần cuối.
     * 2. Xóa đối tượng trên S3 trước (ngoài DB transaction để không chiếm giữ connection).
     * 3. Cập nhật PostgreSQL sau (SOFT_DELETED, không xóa vật lý bản ghi Media).
     * 4. Nếu lỗi S3 -> tính toán Retry + Exponential Backoff.
     */
    public ItemProcessResult processClaimedMedia(UUID jobId, MediaAsset claimedAsset) {
        UUID mediaId = claimedAsset.getId();

        // Bước 1: Kiểm tra lại xem có reference mới nào vừa được gắn không
        boolean hasActiveRef = Boolean.TRUE.equals(
                transactionTemplate.execute(status -> mediaReferenceRepository.existsByMediaIdAndActiveTrue(mediaId))
        );
        if (hasActiveRef) {
            transactionTemplate.executeWithoutResult(status -> {
                mediaAssetRepository.findById(mediaId).ifPresent(asset -> {
                    asset.setStatus(MediaAssetStatus.ACTIVE);
                    asset.setClaimedByJobId(null);
                    asset.setClaimedAt(null);
                    mediaAssetRepository.save(asset);
                });
                mediaCleanupLogRepository.save(MediaCleanupLog.builder()
                        .jobId(jobId)
                        .mediaId(mediaId)
                        .bucketName(claimedAsset.getBucketName())
                        .objectKey(claimedAsset.getObjectKey())
                        .fileSize(claimedAsset.getFileSize())
                        .action(CleanupLogAction.SKIP_REFERENCED)
                        .outcome(CleanupLogOutcome.SKIPPED)
                        .attemptNumber(claimedAsset.getRetryCount() + 1)
                        .durationMs(0L)
                        .build());
            });
            return ItemProcessResult.builder()
                    .outcome(CleanupLogOutcome.SKIPPED)
                    .permanentlyFailed(false)
                    .freedBytes(0L)
                    .build();
        }

        // Bước 2: S3 được xóa trước
        ObjectStorageCleanupClient.StorageDeleteResult s3Result =
                objectStorageCleanupClient.deleteObject(claimedAsset.getBucketName(), claimedAsset.getObjectKey());

        // Bước 3: PostgreSQL cập nhật sau
        if (s3Result.isSuccess()) {
            transactionTemplate.executeWithoutResult(status -> {
                Instant now = Instant.now();
                mediaAssetRepository.findById(mediaId).ifPresent(asset -> {
                    // Quyết định thiết kế: Không xóa vật lý bản ghi Media ngay sau Cleanup
                    asset.setStatus(MediaAssetStatus.SOFT_DELETED);
                    asset.setDeletedAt(now);
                    asset.setClaimedByJobId(null);
                    asset.setClaimedAt(null);
                    asset.setNextRetryAt(null);
                    asset.setLastErrorCode(null);
                    asset.setLastErrorMessage(null);
                    mediaAssetRepository.save(asset);
                });

                mediaCleanupLogRepository.save(MediaCleanupLog.builder()
                        .jobId(jobId)
                        .mediaId(mediaId)
                        .bucketName(claimedAsset.getBucketName())
                        .objectKey(claimedAsset.getObjectKey())
                        .fileSize(claimedAsset.getFileSize())
                        .action(CleanupLogAction.S3_DELETE_AND_SOFT_DELETE)
                        .outcome(CleanupLogOutcome.SUCCESS)
                        .attemptNumber(claimedAsset.getRetryCount() + 1)
                        .durationMs(s3Result.getDurationMs())
                        .build());
            });

            return ItemProcessResult.builder()
                    .outcome(CleanupLogOutcome.SUCCESS)
                    .permanentlyFailed(false)
                    .freedBytes(claimedAsset.getFileSize())
                    .build();
        }

        // Bước 4: Xử lý lỗi với Retry + Exponential Backoff
        int nextAttempt = claimedAsset.getRetryCount() + 1;
        int maxRetries = claimedAsset.getMaxRetries() > 0 ? claimedAsset.getMaxRetries() : properties.getMaxRetries();
        boolean exhausted = nextAttempt >= maxRetries;
        Instant nextRetryAt = exhausted ? null : calculateExponentialBackoff(nextAttempt);

        transactionTemplate.executeWithoutResult(status -> {
            mediaAssetRepository.findById(mediaId).ifPresent(asset -> {
                asset.setRetryCount(nextAttempt);
                asset.setClaimedByJobId(null);
                asset.setClaimedAt(null);
                asset.setLastErrorCode(s3Result.getErrorCode());
                asset.setLastErrorMessage(s3Result.getErrorMessage());
                if (exhausted) {
                    asset.setStatus(MediaAssetStatus.FAILED_PERMANENT);
                    asset.setNextRetryAt(null);
                } else {
                    asset.setStatus(MediaAssetStatus.ACTIVE);
                    asset.setNextRetryAt(nextRetryAt);
                }
                mediaAssetRepository.save(asset);
            });

            mediaCleanupLogRepository.save(MediaCleanupLog.builder()
                    .jobId(jobId)
                    .mediaId(mediaId)
                    .bucketName(claimedAsset.getBucketName())
                    .objectKey(claimedAsset.getObjectKey())
                    .fileSize(claimedAsset.getFileSize())
                    .action(exhausted ? CleanupLogAction.MARK_PERMANENT_FAILED : CleanupLogAction.RETRY_SCHEDULED)
                    .outcome(CleanupLogOutcome.FAILED)
                    .attemptNumber(nextAttempt)
                    .durationMs(s3Result.getDurationMs())
                    .errorCode(s3Result.getErrorCode())
                    .errorMessage(s3Result.getErrorMessage())
                    .build());
        });

        return ItemProcessResult.builder()
                .outcome(CleanupLogOutcome.FAILED)
                .permanentlyFailed(exhausted)
                .freedBytes(0L)
                .build();
    }

    /**
     * Tính thời điểm retry tiếp theo theo thuật toán Exponential Backoff có Jitter:
     * delay = min(maxBackoffMinutes, baseBackoffMinutes * 2^(retryAttempt - 1)) + jitter(0..30s)
     */
    public Instant calculateExponentialBackoff(int retryAttempt) {
        long baseMinutes = Math.max(1L, properties.getBaseBackoffMinutes());
        long maxMinutes = Math.max(baseMinutes, properties.getMaxBackoffMinutes());
        int exponent = Math.min(10, Math.max(0, retryAttempt - 1));
        long delayMinutes = Math.min(maxMinutes, baseMinutes * (1L << exponent));
        long jitterSeconds = ThreadLocalRandom.current().nextLong(0, 31);
        return Instant.now().plusSeconds(delayMinutes * 60L + jitterSeconds);
    }
}

