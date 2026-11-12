package com.suachuabientan.system_internal.modules.mediacleanup.scheduler;

import com.suachuabientan.system_internal.modules.mediacleanup.config.MediaCleanupProperties;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupTriggerType;
import com.suachuabientan.system_internal.modules.mediacleanup.service.MediaCleanupEngineService;
import com.suachuabientan.system_internal.modules.mediacleanup.service.MediaCleanupRecoveryService;
import com.suachuabientan.system_internal.modules.mediacleanup.service.MediaCleanupScheduleService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import net.javacrumbs.shedlock.spring.annotation.SchedulerLock;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class MediaCleanupScheduler {

    private final MediaCleanupProperties properties;
    private final MediaCleanupEngineService cleanupEngineService;
    private final MediaCleanupRecoveryService recoveryService;
    private final MediaCleanupScheduleService scheduleService;

    /**
     * Kiểm tra mốc thời gian hẹn chạy Media Cleanup do Admin cấu hình trên giao diện.
     * - Không tự động xóa liên tục hàng ngày nếu Admin chưa bật lịch hẹn.
     * - Chỉ thực thi đúng khi thời gian hiện tại chạm mốc `scheduled_run_at` đã cấu hình.
     * - Sử dụng ShedLock kết hợp với PostgreSQL Row Lock (FOR UPDATE SKIP LOCKED) trong Engine.
     */
    @Scheduled(cron = "${app.media-cleanup.check-cron:0 * * * * *}", zone = "Asia/Ho_Chi_Minh")
    @SchedulerLock(
            name = "mediaCleanupEngineJob",
            lockAtLeastFor = "PT30S",
            lockAtMostFor = "PT30M"
    )
    public void checkAndRunScheduledCleanup() {
        if (!properties.isEnabled()) {
            return;
        }
        if (scheduleService.checkAndAcquireDueSchedule()) {
            log.info("Đã đến mốc thời gian hẹn chạy Media Cleanup; bắt đầu thực thi...");
            cleanupEngineService.executeCleanupJob(CleanupTriggerType.SCHEDULED);
        }
    }

    /**
     * Quyết định thiết kế: Có thể retry và phục hồi job sau khi Application restart.
     * Khi ứng dụng vừa khởi động xong, tự động quét và giải phóng các bản ghi CLEANUP_IN_PROGRESS
     * hoặc Job RUNNING bị gián đoạn trước đó.
     */
    @EventListener(ApplicationReadyEvent.class)
    public void onApplicationReadyRecoverStuckJobs() {
        if (!properties.isEnabled()) {
            return;
        }
        try {
            MediaCleanupRecoveryService.RecoverySummary summary = recoveryService.recoverStuckState();
            if (summary.getRecoveredJobs() > 0 || summary.getRecoveredMediaAssets() > 0) {
                log.info("Startup Recovery phát hiện {} job và {} media bị gián đoạn; kích hoạt chạy phục hồi...",
                        summary.getRecoveredJobs(), summary.getRecoveredMediaAssets());
                cleanupEngineService.executeCleanupJob(CleanupTriggerType.STARTUP_RECOVERY);
            }
        } catch (Exception ex) {
            log.warn("Không thể chạy kiểm tra phục hồi Media Cleanup khi khởi động: {}", ex.getMessage());
        }
    }
}
