package com.suachuabientan.system_internal.modules.mediacleanup.service;

import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.mediacleanup.config.MediaCleanupProperties;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaAsset;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaCleanupJob;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaCleanupLog;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupJobStatus;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupLogAction;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupLogOutcome;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupTriggerType;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.MediaAssetStatus;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.MediaModuleSource;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaAssetRepository;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaCleanupJobRepository;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaCleanupLogRepository;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaReferenceRepository;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.transaction.TransactionStatus;
import org.springframework.transaction.support.SimpleTransactionStatus;
import org.springframework.transaction.support.TransactionCallback;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Consumer;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MediaCleanupEngineServiceTest {

    @Mock
    private MediaAssetRepository mediaAssetRepository;

    @Mock
    private MediaReferenceRepository mediaReferenceRepository;

    @Mock
    private MediaCleanupJobRepository mediaCleanupJobRepository;

    @Mock
    private MediaCleanupLogRepository mediaCleanupLogRepository;

    @Mock
    private ObjectStorageCleanupClient objectStorageCleanupClient;

    @Mock
    private NotificationService notificationService;

    @Mock
    private TransactionTemplate transactionTemplate;

    private MediaCleanupProperties properties;
    private MediaCleanupBatchWorker batchWorker;
    private MediaCleanupRecoveryService recoveryService;
    private MediaCleanupEngineService engineService;

    @BeforeEach
    void setUp() {
        properties = new MediaCleanupProperties();
        properties.setEnabled(true);
        properties.setCron("0 0 2 * * *");
        properties.setBatchSize(100);
        properties.setMaxBatchesPerRun(10);
        properties.setMaxRetries(5);
        properties.setBaseBackoffMinutes(5);
        properties.setMaxBackoffMinutes(360);
        properties.setStuckTimeoutMinutes(15);

        lenient().when(transactionTemplate.execute(any())).thenAnswer(invocation -> {
            TransactionCallback<?> callback = invocation.getArgument(0);
            return callback.doInTransaction(new SimpleTransactionStatus());
        });
        lenient().doAnswer(invocation -> {
            Consumer<TransactionStatus> action = invocation.getArgument(0);
            action.accept(new SimpleTransactionStatus());
            return null;
        }).when(transactionTemplate).executeWithoutResult(any());

        batchWorker = new MediaCleanupBatchWorker(
                mediaAssetRepository,
                mediaReferenceRepository,
                mediaCleanupLogRepository,
                objectStorageCleanupClient,
                properties,
                transactionTemplate
        );

        recoveryService = new MediaCleanupRecoveryService(
                mediaAssetRepository,
                mediaCleanupJobRepository,
                mediaCleanupLogRepository,
                properties
        );

        engineService = new MediaCleanupEngineService(
                properties,
                batchWorker,
                recoveryService,
                mediaAssetRepository,
                mediaCleanupJobRepository,
                notificationService,
                new SimpleMeterRegistry()
        );
    }

    @Test
    @DisplayName("Claim theo batch 100 bản ghi hết hạn và không còn reference bằng PostgreSQL FOR UPDATE SKIP LOCKED")
    void claimNextBatchShouldClaimUpTo100ExpiredUnreferencedRecords() {
        UUID jobId = UUID.randomUUID();
        List<MediaAsset> candidates = new ArrayList<>();
        for (int i = 0; i < 100; i++) {
            candidates.add(MediaAsset.builder()
                    .id(UUID.randomUUID())
                    .bucketName("chat-media")
                    .objectKey("expired-" + i + ".jpg")
                    .fileSize(1024L)
                    .moduleSource(MediaModuleSource.MESSAGING)
                    .status(MediaAssetStatus.ACTIVE)
                    .expiresAt(Instant.now().minus(1, ChronoUnit.DAYS))
                    .build());
        }

        when(mediaAssetRepository.findCandidatesForCleanupWithRowLock(any(Instant.class), eq(100)))
                .thenReturn(candidates);
        when(mediaAssetRepository.saveAll(any())).thenAnswer(inv -> inv.getArgument(0));

        List<MediaAsset> claimed = batchWorker.claimNextBatch(jobId, 100);

        assertThat(claimed).hasSize(100);
        assertThat(claimed).allSatisfy(asset -> {
            assertThat(asset.getStatus()).isEqualTo(MediaAssetStatus.CLEANUP_IN_PROGRESS);
            assertThat(asset.getClaimedByJobId()).isEqualTo(jobId);
            assertThat(asset.getClaimedAt()).isNotNull();
        });
    }

    @Test
    @DisplayName("S3 được xóa trước, PostgreSQL cập nhật SOFT_DELETED sau và KHÔNG xóa vật lý bản ghi Media")
    void processClaimedMediaShouldDeleteS3FirstThenSoftDeleteInPostgresWithoutPhysicalDelete() {
        UUID jobId = UUID.randomUUID();
        UUID mediaId = UUID.randomUUID();
        MediaAsset asset = MediaAsset.builder()
                .id(mediaId)
                .bucketName("repair-media")
                .objectKey("invoice-01.pdf")
                .fileSize(20480L)
                .moduleSource(MediaModuleSource.REPAIR)
                .status(MediaAssetStatus.CLEANUP_IN_PROGRESS)
                .expiresAt(Instant.now().minus(2, ChronoUnit.DAYS))
                .retryCount(0)
                .maxRetries(5)
                .build();

        when(mediaReferenceRepository.existsByMediaIdAndActiveTrue(mediaId)).thenReturn(false);
        when(objectStorageCleanupClient.deleteObject("repair-media", "invoice-01.pdf"))
                .thenReturn(ObjectStorageCleanupClient.StorageDeleteResult.builder()
                        .success(true)
                        .alreadyAbsent(false)
                        .durationMs(42L)
                        .build());
        when(mediaAssetRepository.findById(mediaId)).thenReturn(Optional.of(asset));

        MediaCleanupBatchWorker.ItemProcessResult result = batchWorker.processClaimedMedia(jobId, asset);

        assertThat(result.getOutcome()).isEqualTo(CleanupLogOutcome.SUCCESS);
        assertThat(result.getFreedBytes()).isEqualTo(20480L);
        assertThat(asset.getStatus()).isEqualTo(MediaAssetStatus.SOFT_DELETED);
        assertThat(asset.getDeletedAt()).isNotNull();
        assertThat(asset.getClaimedByJobId()).isNull();

        // Đảm bảo thứ tự: xóa S3 trước -> cập nhật PostgreSQL sau
        InOrder inOrder = inOrder(objectStorageCleanupClient, mediaAssetRepository, mediaCleanupLogRepository);
        inOrder.verify(objectStorageCleanupClient).deleteObject("repair-media", "invoice-01.pdf");
        inOrder.verify(mediaAssetRepository).save(asset);
        inOrder.verify(mediaCleanupLogRepository).save(any(MediaCleanupLog.class));

        // Đảm bảo KHÔNG xóa vật lý bản ghi Media
        verify(mediaAssetRepository, never()).delete(any(MediaAsset.class));
        verify(mediaAssetRepository, never()).deleteById(any(UUID.class));
    }

    @Test
    @DisplayName("Bỏ qua Media nếu phát hiện còn reference đang active và không gọi xóa S3")
    void processClaimedMediaShouldSkipWhenActiveReferenceExists() {
        UUID jobId = UUID.randomUUID();
        UUID mediaId = UUID.randomUUID();
        MediaAsset asset = MediaAsset.builder()
                .id(mediaId)
                .bucketName("chat-media")
                .objectKey("referenced.png")
                .fileSize(4096L)
                .moduleSource(MediaModuleSource.MESSAGING)
                .status(MediaAssetStatus.CLEANUP_IN_PROGRESS)
                .expiresAt(Instant.now().minus(1, ChronoUnit.DAYS))
                .build();

        when(mediaReferenceRepository.existsByMediaIdAndActiveTrue(mediaId)).thenReturn(true);
        when(mediaAssetRepository.findById(mediaId)).thenReturn(Optional.of(asset));

        MediaCleanupBatchWorker.ItemProcessResult result = batchWorker.processClaimedMedia(jobId, asset);

        assertThat(result.getOutcome()).isEqualTo(CleanupLogOutcome.SKIPPED);
        assertThat(asset.getStatus()).isEqualTo(MediaAssetStatus.ACTIVE);
        verify(objectStorageCleanupClient, never()).deleteObject(any(), any());

        ArgumentCaptor<MediaCleanupLog> logCaptor = ArgumentCaptor.forClass(MediaCleanupLog.class);
        verify(mediaCleanupLogRepository).save(logCaptor.capture());
        assertThat(logCaptor.getValue().getAction()).isEqualTo(CleanupLogAction.SKIP_REFERENCED);
    }

    @Test
    @DisplayName("Retry + Exponential Backoff khi xóa S3 thất bại và chuyển FAILED_PERMANENT khi hết lượt retry")
    void processClaimedMediaShouldScheduleExponentialBackoffAndMarkPermanentFailureWhenExhausted() {
        UUID jobId = UUID.randomUUID();
        UUID mediaId = UUID.randomUUID();
        MediaAsset asset = MediaAsset.builder()
                .id(mediaId)
                .bucketName("chat-media")
                .objectKey("transient-error.mp4")
                .fileSize(8192L)
                .moduleSource(MediaModuleSource.MESSAGING)
                .status(MediaAssetStatus.CLEANUP_IN_PROGRESS)
                .expiresAt(Instant.now().minus(1, ChronoUnit.DAYS))
                .retryCount(0)
                .maxRetries(3)
                .build();

        when(mediaReferenceRepository.existsByMediaIdAndActiveTrue(mediaId)).thenReturn(false);
        when(objectStorageCleanupClient.deleteObject("chat-media", "transient-error.mp4"))
                .thenReturn(ObjectStorageCleanupClient.StorageDeleteResult.builder()
                        .success(false)
                        .durationMs(120L)
                        .errorCode("SlowDown")
                        .errorMessage("S3 throttling error")
                        .build());
        when(mediaAssetRepository.findById(mediaId)).thenReturn(Optional.of(asset));

        // Lần 1 thất bại -> retryCount = 1, status = ACTIVE, nextRetryAt > now + 5m
        Instant beforeAttempt1 = Instant.now();
        MediaCleanupBatchWorker.ItemProcessResult attempt1 = batchWorker.processClaimedMedia(jobId, asset);
        assertThat(attempt1.getOutcome()).isEqualTo(CleanupLogOutcome.FAILED);
        assertThat(attempt1.isPermanentlyFailed()).isFalse();
        assertThat(asset.getRetryCount()).isEqualTo(1);
        assertThat(asset.getStatus()).isEqualTo(MediaAssetStatus.ACTIVE);
        assertThat(asset.getNextRetryAt()).isAfter(beforeAttempt1.plus(4, ChronoUnit.MINUTES));

        // Lần 2 thất bại -> retryCount = 2, backoff tăng gấp đôi (~10 phút)
        Instant beforeAttempt2 = Instant.now();
        MediaCleanupBatchWorker.ItemProcessResult attempt2 = batchWorker.processClaimedMedia(jobId, asset);
        assertThat(attempt2.isPermanentlyFailed()).isFalse();
        assertThat(asset.getRetryCount()).isEqualTo(2);
        assertThat(asset.getNextRetryAt()).isAfter(beforeAttempt2.plus(9, ChronoUnit.MINUTES));

        // Lần 3 thất bại (đạt maxRetries = 3) -> chuyển sang FAILED_PERMANENT
        MediaCleanupBatchWorker.ItemProcessResult attempt3 = batchWorker.processClaimedMedia(jobId, asset);
        assertThat(attempt3.getOutcome()).isEqualTo(CleanupLogOutcome.FAILED);
        assertThat(attempt3.isPermanentlyFailed()).isTrue();
        assertThat(asset.getRetryCount()).isEqualTo(3);
        assertThat(asset.getStatus()).isEqualTo(MediaAssetStatus.FAILED_PERMANENT);
        assertThat(asset.getNextRetryAt()).isNull();
    }

    @Test
    @DisplayName("Phục hồi job RUNNING và bản ghi CLEANUP_IN_PROGRESS bị treo sau khi Application restart")
    void recoverStuckStateShouldResetInterruptedJobsAndStuckAssets() {
        UUID stuckJobId = UUID.randomUUID();
        MediaCleanupJob stuckJob = MediaCleanupJob.builder()
                .id(stuckJobId)
                .jobCode("MCJ-20261111-020000-ABC123")
                .triggerType(CleanupTriggerType.SCHEDULED)
                .status(CleanupJobStatus.RUNNING)
                .startedAt(Instant.now().minus(40, ChronoUnit.MINUTES))
                .lastHeartbeatAt(Instant.now().minus(30, ChronoUnit.MINUTES))
                .build();

        MediaAsset stuckAsset = MediaAsset.builder()
                .id(UUID.randomUUID())
                .bucketName("chat-media")
                .objectKey("stuck-after-restart.jpg")
                .fileSize(5000L)
                .status(MediaAssetStatus.CLEANUP_IN_PROGRESS)
                .claimedByJobId(stuckJobId)
                .claimedAt(Instant.now().minus(30, ChronoUnit.MINUTES))
                .retryCount(1)
                .build();

        when(mediaCleanupJobRepository.findByStatusAndLastHeartbeatAtBefore(eq(CleanupJobStatus.RUNNING), any(Instant.class)))
                .thenReturn(List.of(stuckJob));
        when(mediaAssetRepository.findByStatusAndClaimedAtBefore(eq(MediaAssetStatus.CLEANUP_IN_PROGRESS), any(Instant.class)))
                .thenReturn(List.of(stuckAsset));
        when(mediaCleanupJobRepository.existsById(stuckJobId)).thenReturn(true);

        MediaCleanupRecoveryService.RecoverySummary summary = recoveryService.recoverStuckState();

        assertThat(summary.getRecoveredJobs()).isEqualTo(1);
        assertThat(summary.getRecoveredMediaAssets()).isEqualTo(1);
        assertThat(stuckJob.getStatus()).isEqualTo(CleanupJobStatus.INTERRUPTED_RECOVERED);
        assertThat(stuckJob.getFinishedAt()).isNotNull();
        assertThat(stuckAsset.getStatus()).isEqualTo(MediaAssetStatus.ACTIVE);
        assertThat(stuckAsset.getClaimedByJobId()).isNull();
        assertThat(stuckAsset.getClaimedAt()).isNull();

        ArgumentCaptor<MediaCleanupLog> logCaptor = ArgumentCaptor.forClass(MediaCleanupLog.class);
        verify(mediaCleanupLogRepository).save(logCaptor.capture());
        assertThat(logCaptor.getValue().getAction()).isEqualTo(CleanupLogAction.RECOVERY_RESET);
    }

    @Test
    @DisplayName("Thực thi toàn bộ MediaCleanupEngineService: ghi nhận job, metrics và gửi cảnh báo khi có FAILED_PERMANENT")
    void executeCleanupJobShouldCompleteAndSendAlertOnPermanentFailure() {
        UUID jobId = UUID.randomUUID();
        when(mediaCleanupJobRepository.save(any(MediaCleanupJob.class))).thenAnswer(inv -> {
            MediaCleanupJob job = inv.getArgument(0);
            if (job.getId() == null) {
                job.setId(jobId);
            }
            return job;
        });

        when(mediaCleanupJobRepository.findByStatusAndLastHeartbeatAtBefore( any(), any())).thenReturn(List.of());
        when(mediaAssetRepository.findByStatusAndClaimedAtBefore(any(), any())).thenReturn(List.of());

        MediaAsset okAsset = MediaAsset.builder()
                .id(UUID.randomUUID())
                .bucketName("chat-media")
                .objectKey("ok.jpg")
                .fileSize(1000L)
                .status(MediaAssetStatus.ACTIVE)
                .expiresAt(Instant.now().minus(1, ChronoUnit.DAYS))
                .retryCount(0)
                .maxRetries(5)
                .build();

        MediaAsset failPermanentAsset = MediaAsset.builder()
                .id(UUID.randomUUID())
                .bucketName("chat-media")
                .objectKey("perm-fail.jpg")
                .fileSize(2000L)
                .status(MediaAssetStatus.ACTIVE)
                .expiresAt(Instant.now().minus(1, ChronoUnit.DAYS))
                .retryCount(4)
                .maxRetries(5)
                .build();

        when(mediaAssetRepository.findCandidatesForCleanupWithRowLock(any(Instant.class), anyInt()))
                .thenReturn(List.of(okAsset, failPermanentAsset))
                .thenReturn(List.of());
        when(mediaAssetRepository.saveAll(any())).thenAnswer(inv -> inv.getArgument(0));
        when(mediaReferenceRepository.existsByMediaIdAndActiveTrue(any())).thenReturn(false);

        when(objectStorageCleanupClient.deleteObject("chat-media", "ok.jpg"))
                .thenReturn(ObjectStorageCleanupClient.StorageDeleteResult.builder()
                        .success(true)
                        .durationMs(15L)
                        .build());
        when(objectStorageCleanupClient.deleteObject("chat-media", "perm-fail.jpg"))
                .thenReturn(ObjectStorageCleanupClient.StorageDeleteResult.builder()
                        .success(false)
                        .durationMs(20L)
                        .errorCode("AccessDenied")
                        .errorMessage("Access Denied")
                        .build());

        when(mediaAssetRepository.findById(okAsset.getId())).thenReturn(Optional.of(okAsset));
        when(mediaAssetRepository.findById(failPermanentAsset.getId())).thenReturn(Optional.of(failPermanentAsset));

        MediaCleanupJob finishedJob = engineService.executeCleanupJob(CleanupTriggerType.SCHEDULED);

        assertThat(finishedJob.getStatus()).isEqualTo(CleanupJobStatus.PARTIAL_FAILURE);
        assertThat(finishedJob.getTotalBatches()).isEqualTo(1);
        assertThat(finishedJob.getTotalProcessed()).isEqualTo(2);
        assertThat(finishedJob.getDeletedCount()).isEqualTo(1);
        assertThat(finishedJob.getFailedCount()).isEqualTo(1);
        assertThat(finishedJob.getFreedBytes()).isEqualTo(1000L);

        verify(notificationService).sendToRoles(
                eq(List.of(UserRole.SUPER_ADMIN, UserRole.ADMIN)),
                eq(NotificationType.MEDIA_CLEANUP_ALERT),
                any(),
                any(),
                eq("MEDIA_CLEANUP"),
                any(),
                eq(true)
        );
    }
}

