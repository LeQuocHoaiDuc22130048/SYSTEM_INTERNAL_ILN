package com.suachuabientan.system_internal.modules.mediacleanup.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaAsset;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaCleanupJob;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaCleanupLog;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaCleanupScheduleConfig;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupTriggerType;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.MediaAssetStatus;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaAssetRepository;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaCleanupJobRepository;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaCleanupLogRepository;
import com.suachuabientan.system_internal.modules.mediacleanup.service.MediaCleanupEngineService;
import com.suachuabientan.system_internal.modules.mediacleanup.service.MediaCleanupRecoveryService;
import com.suachuabientan.system_internal.modules.mediacleanup.service.MediaCleanupScheduleService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/admin/media-cleanup")
@RequiredArgsConstructor
@Tag(name = "Admin Media Cleanup Engine", description = "Giám sát, cấu hình lịch hẹn, Audit Log và điều khiển Media Cleanup Engine")
@PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
public class MediaCleanupAdminController {

    private final MediaCleanupEngineService cleanupEngineService;
    private final MediaCleanupRecoveryService recoveryService;
    private final MediaCleanupScheduleService scheduleService;
    private final MediaCleanupJobRepository jobRepository;
    private final MediaCleanupLogRepository logRepository;
    private final MediaAssetRepository mediaAssetRepository;

    @Operation(summary = "Xem thống kê tổng quan Media Cleanup Engine")
    @GetMapping("/stats")
    public ResponseEntity<ApiResponse<MediaCleanupEngineService.CleanupDashboardStats>> getStats() {
        return ResponseEntity.ok(ApiResponse.success(cleanupEngineService.getDashboardStats()));
    }

    @Operation(summary = "Xem cấu hình lịch hẹn chạy Media Cleanup")
    @GetMapping("/schedule")
    public ResponseEntity<ApiResponse<MediaCleanupScheduleConfig>> getScheduleConfig() {
        return ResponseEntity.ok(ApiResponse.success(scheduleService.getConfig()));
    }

    @Operation(summary = "Cập nhật cấu hình lịch hẹn / mốc thời gian chạy Media Cleanup")
    @PutMapping("/schedule")
    public ResponseEntity<ApiResponse<MediaCleanupScheduleConfig>> updateScheduleConfig(
            @RequestBody MediaCleanupScheduleService.UpdateScheduleRequest request,
            Authentication authentication
    ) {
        String actor = authentication != null ? authentication.getName() : "ADMIN";
        MediaCleanupScheduleConfig saved = scheduleService.updateConfig(request, actor);
        return ResponseEntity.ok(ApiResponse.success(saved, "Đã lưu cấu hình lịch hẹn Media Cleanup"));
    }

    @Operation(summary = "Danh sách lịch sử các phiên chạy Cleanup Job")
    @GetMapping("/jobs")
    public ResponseEntity<ApiResponse<Page<MediaCleanupJob>>> getJobs(
            @PageableDefault(size = 20) Pageable pageable
    ) {
        return ResponseEntity.ok(ApiResponse.success(jobRepository.findAllByOrderByStartedAtDesc(pageable)));
    }

    @Operation(summary = "Xem nhật ký Audit Log chi tiết của một phiên chạy Cleanup Job")
    @GetMapping("/jobs/{jobId}/logs")
    public ResponseEntity<ApiResponse<Page<MediaCleanupLog>>> getJobLogs(
            @PathVariable UUID jobId,
            @PageableDefault(size = 50) Pageable pageable
    ) {
        return ResponseEntity.ok(ApiResponse.success(logRepository.findByJobIdOrderByCreatedAtDesc(jobId, pageable)));
    }

    @Operation(summary = "Danh sách các bản ghi Media theo trạng thái (ACTIVE, SOFT_DELETED, FAILED_PERMANENT)")
    @GetMapping("/assets")
    public ResponseEntity<ApiResponse<Page<MediaAsset>>> getAssetsByStatus(
            @RequestParam(defaultValue = "FAILED_PERMANENT") MediaAssetStatus status,
            @PageableDefault(size = 20) Pageable pageable
    ) {
        return ResponseEntity.ok(ApiResponse.success(mediaAssetRepository.findByStatusOrderByUpdatedAtDesc(status, pageable)));
    }

    @Operation(summary = "Kích hoạt chạy Media Cleanup thủ công ngay lập tức")
    @PostMapping("/trigger")
    public ResponseEntity<ApiResponse<MediaCleanupJob>> triggerManualCleanup() {
        MediaCleanupJob job = cleanupEngineService.executeCleanupJob(CleanupTriggerType.MANUAL_ADMIN);
        return ResponseEntity.ok(ApiResponse.success(job, "Đã thực thi phiên dọn dẹp Media thành công"));
    }

    @Operation(summary = "Chạy phục hồi các Job/Media bị kẹt (Stuck Recovery)")
    @PostMapping("/recover")
    public ResponseEntity<ApiResponse<MediaCleanupRecoveryService.RecoverySummary>> recoverStuckJobs() {
        MediaCleanupRecoveryService.RecoverySummary summary = recoveryService.recoverStuckState();
        return ResponseEntity.ok(ApiResponse.success(summary, "Đã hoàn tất kiểm tra và phục hồi trạng thái treo"));
    }

    @Operation(summary = "Đặt lại (Reset) một bản ghi Media lỗi để thử xóa lại ở chu kỳ tiếp theo")
    @PostMapping("/assets/{mediaId}/retry")
    public ResponseEntity<ApiResponse<MediaAsset>> retryMediaAsset(@PathVariable UUID mediaId) {
        MediaAsset updated = cleanupEngineService.resetMediaForImmediateRetry(mediaId);
        return ResponseEntity.ok(ApiResponse.success(updated, "Đã đặt lại trạng thái retry cho bản ghi Media"));
    }
}
