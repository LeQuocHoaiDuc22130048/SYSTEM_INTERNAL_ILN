package com.suachuabientan.system_internal.modules.mediacleanup.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaAsset;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaCleanupJob;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaCleanupLog;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaCleanupScheduleConfig;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupJobStatus;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupLogAction;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupLogOutcome;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupScheduleMode;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupTriggerType;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.MediaAssetStatus;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaAssetRepository;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaCleanupJobRepository;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaCleanupLogRepository;
import com.suachuabientan.system_internal.modules.mediacleanup.service.MediaCleanupEngineService;
import com.suachuabientan.system_internal.modules.mediacleanup.service.MediaCleanupRecoveryService;
import com.suachuabientan.system_internal.modules.mediacleanup.service.MediaCleanupScheduleService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MediaCleanupAdminControllerTest {

    @Mock
    private MediaCleanupEngineService cleanupEngineService;

    @Mock
    private MediaCleanupRecoveryService recoveryService;

    @Mock
    private MediaCleanupScheduleService scheduleService;

    @Mock
    private MediaCleanupJobRepository jobRepository;

    @Mock
    private MediaCleanupLogRepository logRepository;

    @Mock
    private MediaAssetRepository mediaAssetRepository;

    private MediaCleanupAdminController controller;

    @BeforeEach
    void setUp() {
        controller = new MediaCleanupAdminController(
                cleanupEngineService,
                recoveryService,
                scheduleService,
                jobRepository,
                logRepository,
                mediaAssetRepository
        );
    }

    @Test
    @DisplayName("GET /api/v1/admin/media-cleanup/stats trả về thống kê giám sát đầy đủ")
    void getStatsShouldReturnDashboardStats() {
        MediaCleanupEngineService.CleanupDashboardStats stats = MediaCleanupEngineService.CleanupDashboardStats.builder()
                .engineEnabled(true)
                .cronExpression("0 0 2 * * *")
                .batchSize(100)
                .activeMediaCount(42L)
                .eligibleExpiredCandidates(5L)
                .cleanupInProgressCount(0L)
                .softDeletedMediaCount(120L)
                .permanentlyFailedMediaCount(1L)
                .totalFreedBytes(10485760L)
                .build();

        when(cleanupEngineService.getDashboardStats()).thenReturn(stats);

        ResponseEntity<ApiResponse<MediaCleanupEngineService.CleanupDashboardStats>> response = controller.getStats();

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getData().getBatchSize()).isEqualTo(100);
        assertThat(response.getBody().getData().getSoftDeletedMediaCount()).isEqualTo(120L);
    }

    @Test
    @DisplayName("GET & PUT /api/v1/admin/media-cleanup/schedule cho phép Admin hẹn đúng mốc ngày giờ chạy Cleanup")
    void scheduleEndpointsShouldGetAndUpdateSpecificDateTimeSchedule() {
        Instant targetRunAt = Instant.now().plus(3, ChronoUnit.DAYS);
        MediaCleanupScheduleConfig cfg = MediaCleanupScheduleConfig.builder()
                .id(1)
                .enabled(true)
                .scheduleMode(CleanupScheduleMode.SPECIFIC_DATETIME)
                .scheduledRunAt(targetRunAt)
                .unreferencedUploadTtlHours(24)
                .deletedMessageMediaTtlDays(7)
                .closedRepairMediaTtlDays(180)
                .build();

        when(scheduleService.getConfig()).thenReturn(cfg);
        when(scheduleService.updateConfig(any(), eq("ADMIN"))).thenReturn(cfg);

        ResponseEntity<ApiResponse<MediaCleanupScheduleConfig>> getRes = controller.getScheduleConfig();
        assertThat(getRes.getBody().getData().getScheduleMode()).isEqualTo(CleanupScheduleMode.SPECIFIC_DATETIME);
        assertThat(getRes.getBody().getData().getScheduledRunAt()).isEqualTo(targetRunAt);

        MediaCleanupScheduleService.UpdateScheduleRequest updateReq =
                MediaCleanupScheduleService.UpdateScheduleRequest.builder()
                        .enabled(true)
                        .scheduleMode(CleanupScheduleMode.SPECIFIC_DATETIME)
                        .scheduledRunAt(targetRunAt)
                        .build();

        ResponseEntity<ApiResponse<MediaCleanupScheduleConfig>> putRes =
                controller.updateScheduleConfig(updateReq, null);
        assertThat(putRes.getBody().getData().isEnabled()).isTrue();
        assertThat(putRes.getBody().getData().getScheduledRunAt()).isEqualTo(targetRunAt);
    }

    @Test
    @DisplayName("GET /api/v1/admin/media-cleanup/jobs/{jobId}/logs trả về danh sách Audit Log của phiên")
    void getJobLogsShouldReturnAuditLogsForJob() {
        UUID jobId = UUID.randomUUID();
        MediaCleanupLog logEntry = MediaCleanupLog.builder()
                .id(UUID.randomUUID())
                .jobId(jobId)
                .mediaId(UUID.randomUUID())
                .bucketName("chat-media")
                .objectKey("expired.jpg")
                .fileSize(4096L)
                .action(CleanupLogAction.S3_DELETE_AND_SOFT_DELETE)
                .outcome(CleanupLogOutcome.SUCCESS)
                .attemptNumber(1)
                .durationMs(25L)
                .createdAt(Instant.now())
                .build();

        when(logRepository.findByJobIdOrderByCreatedAtDesc(eq(jobId), any()))
                .thenReturn(new PageImpl<>(List.of(logEntry)));

        ResponseEntity<ApiResponse<Page<MediaCleanupLog>>> response =
                controller.getJobLogs(jobId, PageRequest.of(0, 50));

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody().getData().getContent()).hasSize(1);
        assertThat(response.getBody().getData().getContent().get(0).getAction())
                .isEqualTo(CleanupLogAction.S3_DELETE_AND_SOFT_DELETE);
    }

    @Test
    @DisplayName("POST /api/v1/admin/media-cleanup/trigger kích hoạt chạy Cleanup thủ công")
    void triggerManualCleanupShouldExecuteJobWithManualAdminTrigger() {
        MediaCleanupJob job = MediaCleanupJob.builder()
                .id(UUID.randomUUID())
                .jobCode("MCJ-20261111-150000-MANUAL")
                .triggerType(CleanupTriggerType.MANUAL_ADMIN)
                .status(CleanupJobStatus.COMPLETED)
                .batchSize(100)
                .deletedCount(12)
                .freedBytes(65536L)
                .build();

        when(cleanupEngineService.executeCleanupJob(CleanupTriggerType.MANUAL_ADMIN)).thenReturn(job);

        ResponseEntity<ApiResponse<MediaCleanupJob>> response = controller.triggerManualCleanup();

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody().getData().getTriggerType()).isEqualTo(CleanupTriggerType.MANUAL_ADMIN);
        verify(cleanupEngineService).executeCleanupJob(CleanupTriggerType.MANUAL_ADMIN);
    }

    @Test
    @DisplayName("POST /api/v1/admin/media-cleanup/recover & /assets/{mediaId}/retry hoạt động chuẩn xác")
    void recoverAndRetryEndpointsShouldInvokeServices() {
        MediaCleanupRecoveryService.RecoverySummary summary = MediaCleanupRecoveryService.RecoverySummary.builder()
                .recoveredJobs(1)
                .recoveredMediaAssets(3)
                .build();
        when(recoveryService.recoverStuckState()).thenReturn(summary);

        ResponseEntity<ApiResponse<MediaCleanupRecoveryService.RecoverySummary>> recoverRes =
                controller.recoverStuckJobs();
        assertThat(recoverRes.getBody().getData().getRecoveredJobs()).isEqualTo(1);
        assertThat(recoverRes.getBody().getData().getRecoveredMediaAssets()).isEqualTo(3);

        UUID mediaId = UUID.randomUUID();
        MediaAsset resetAsset = MediaAsset.builder()
                .id(mediaId)
                .status(MediaAssetStatus.ACTIVE)
                .retryCount(0)
                .build();
        when(cleanupEngineService.resetMediaForImmediateRetry(mediaId)).thenReturn(resetAsset);

        ResponseEntity<ApiResponse<MediaAsset>> retryRes = controller.retryMediaAsset(mediaId);
        assertThat(retryRes.getBody().getData().getStatus()).isEqualTo(MediaAssetStatus.ACTIVE);
        assertThat(retryRes.getBody().getData().getRetryCount()).isZero();
    }
}
