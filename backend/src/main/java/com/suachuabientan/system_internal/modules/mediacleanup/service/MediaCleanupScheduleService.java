package com.suachuabientan.system_internal.modules.mediacleanup.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.modules.mediacleanup.config.MediaCleanupProperties;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaCleanupScheduleConfig;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupScheduleMode;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaCleanupScheduleConfigRepository;
import lombok.Builder;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import lombok.Setter;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.*;
import java.time.temporal.TemporalAdjusters;

@Slf4j
@Service
@RequiredArgsConstructor
public class MediaCleanupScheduleService {

    private static final int SINGLETON_ID = 1;
    private static final ZoneId VN_ZONE = ZoneId.of("Asia/Ho_Chi_Minh");

    private final MediaCleanupScheduleConfigRepository scheduleRepository;
    private final MediaCleanupProperties properties;

    @Getter
    @Setter
    @Builder
    public static class UpdateScheduleRequest {
        private Boolean enabled;
        private CleanupScheduleMode scheduleMode;
        private Instant scheduledRunAt;
        private Integer dayOfMonth;
        private Integer dayOfWeek;
        private String timeOfDay;
        private Long unreferencedUploadTtlHours;
        private Long deletedMessageMediaTtlDays;
        private Long closedRepairMediaTtlDays;
    }

    @Transactional(readOnly = true)
    public MediaCleanupScheduleConfig getConfig() {
        return scheduleRepository.findById(SINGLETON_ID)
                .orElseGet(this::buildDefaultConfig);
    }

    @Transactional
    public MediaCleanupScheduleConfig updateConfig(UpdateScheduleRequest request, String updatedBy) {
        MediaCleanupScheduleConfig config = scheduleRepository.findById(SINGLETON_ID)
                .orElseGet(this::buildDefaultConfig);

        if (request.getEnabled() != null) {
            config.setEnabled(request.getEnabled());
        }
        if (request.getScheduleMode() != null) {
            config.setScheduleMode(request.getScheduleMode());
        }
        if (request.getDayOfMonth() != null) {
            config.setDayOfMonth(Math.min(28, Math.max(1, request.getDayOfMonth())));
        }
        if (request.getDayOfWeek() != null) {
            config.setDayOfWeek(Math.min(7, Math.max(1, request.getDayOfWeek())));
        }
        if (request.getTimeOfDay() != null && !request.getTimeOfDay().isBlank()) {
            validateTimeOfDay(request.getTimeOfDay().trim());
            config.setTimeOfDay(request.getTimeOfDay().trim());
        }
        if (request.getUnreferencedUploadTtlHours() != null && request.getUnreferencedUploadTtlHours() >= 1) {
            config.setUnreferencedUploadTtlHours(request.getUnreferencedUploadTtlHours());
            properties.setUnreferencedUploadTtlHours(request.getUnreferencedUploadTtlHours());
        }
        if (request.getDeletedMessageMediaTtlDays() != null && request.getDeletedMessageMediaTtlDays() >= 0) {
            config.setDeletedMessageMediaTtlDays(request.getDeletedMessageMediaTtlDays());
            properties.setDeletedMessageMediaTtlDays(request.getDeletedMessageMediaTtlDays());
        }
        if (request.getClosedRepairMediaTtlDays() != null && request.getClosedRepairMediaTtlDays() >= 1) {
            config.setClosedRepairMediaTtlDays(request.getClosedRepairMediaTtlDays());
            properties.setClosedRepairMediaTtlDays(request.getClosedRepairMediaTtlDays());
        }

        if (config.getScheduleMode() == CleanupScheduleMode.SPECIFIC_DATETIME) {
            if (request.getScheduledRunAt() != null) {
                config.setScheduledRunAt(request.getScheduledRunAt());
            } else if (config.isEnabled() && config.getScheduledRunAt() == null) {
                throw new BusinessException("Vui lòng chọn ngày và giờ cụ thể để hẹn chạy Media Cleanup.");
            }
        } else {
            config.setScheduledRunAt(computeNextRecurringRun(config, Instant.now()));
        }

        config.setUpdatedBy(updatedBy);
        config.setUpdatedAt(Instant.now());
        return scheduleRepository.save(config);
    }

    /**
     * Kiểm tra xem hiện tại đã đến mốc thời gian xác định để chạy Media Cleanup chưa.
     * Nếu đã đến hạn:
     * - Với chế độ SPECIFIC_DATETIME: chỉ chạy ĐÚNG 1 LẦN tại mốc đã hẹn, sau đó tự động tắt cờ enabled
     *   để đảm bảo KHÔNG chạy lặp lại liên tục.
     * - Với chế độ định kỳ (MONTHLY / WEEKLY / DAILY): tính mốc chạy kế tiếp sau khi kích hoạt.
     */
    @Transactional
    public boolean checkAndAcquireDueSchedule() {
        MediaCleanupScheduleConfig config = scheduleRepository.findById(SINGLETON_ID).orElse(null);
        if (config == null || !config.isEnabled() || config.getScheduledRunAt() == null) {
            return false;
        }

        Instant now = Instant.now();
        Instant target = config.getScheduledRunAt();
        if (now.isBefore(target)) {
            return false;
        }

        // Tránh chạy trùng lặp cùng một mốc thời gian
        if (config.getLastTriggeredAt() != null && !config.getLastTriggeredAt().isBefore(target)) {
            if (config.getScheduleMode() == CleanupScheduleMode.SPECIFIC_DATETIME) {
                config.setEnabled(false);
                scheduleRepository.save(config);
                return false;
            }
        }

        config.setLastTriggeredAt(now);
        if (config.getScheduleMode() == CleanupScheduleMode.SPECIFIC_DATETIME) {
            // Đã chạy tại thời điểm xác định -> tắt tự động chạy lại cho tới khi Admin hẹn mốc mới
            config.setEnabled(false);
        } else {
            config.setScheduledRunAt(computeNextRecurringRun(config, now.plusSeconds(60)));
        }
        scheduleRepository.save(config);
        return true;
    }

    public Instant computeNextRecurringRun(MediaCleanupScheduleConfig config, Instant referenceInstant) {
        LocalTime localTime = parseLocalTime(config.getTimeOfDay());
        ZonedDateTime nowZoned = referenceInstant.atZone(VN_ZONE);

        return switch (config.getScheduleMode()) {
            case DAILY -> {
                ZonedDateTime candidate = nowZoned.with(localTime);
                if (!candidate.isAfter(nowZoned)) {
                    candidate = candidate.plusDays(1);
                }
                yield candidate.toInstant();
            }
            case WEEKLY -> {
                int dow = config.getDayOfWeek() != null ? Math.min(7, Math.max(1, config.getDayOfWeek())) : 1;
                DayOfWeek targetDay = DayOfWeek.of(dow);
                ZonedDateTime candidate = nowZoned.with(TemporalAdjusters.nextOrSame(targetDay)).with(localTime);
                if (!candidate.isAfter(nowZoned)) {
                    candidate = candidate.plusWeeks(1);
                }
                yield candidate.toInstant();
            }
            case MONTHLY -> {
                int dom = config.getDayOfMonth() != null ? Math.min(28, Math.max(1, config.getDayOfMonth())) : 1;
                ZonedDateTime candidate = nowZoned.withDayOfMonth(dom).with(localTime);
                if (!candidate.isAfter(nowZoned)) {
                    candidate = candidate.plusMonths(1).withDayOfMonth(dom).with(localTime);
                }
                yield candidate.toInstant();
            }
            case SPECIFIC_DATETIME -> config.getScheduledRunAt();
        };
    }

    private void validateTimeOfDay(String timeStr) {
        try {
            LocalTime.parse(timeStr.length() == 5 ? timeStr : "0" + timeStr);
        } catch (Exception ex) {
            throw new BusinessException("Định dạng giờ không hợp lệ (cần HH:mm, ví dụ 02:00)");
        }
    }

    private LocalTime parseLocalTime(String timeStr) {
        try {
            if (timeStr == null || timeStr.isBlank()) {
                return LocalTime.of(2, 0);
            }
            String normalized = timeStr.trim();
            if (normalized.length() == 4 && normalized.indexOf(':') == 1) {
                normalized = "0" + normalized;
            }
            return LocalTime.parse(normalized);
        } catch (Exception ex) {
            return LocalTime.of(2, 0);
        }
    }

    private MediaCleanupScheduleConfig buildDefaultConfig() {
        return MediaCleanupScheduleConfig.builder()
                .id(SINGLETON_ID)
                .enabled(false)
                .scheduleMode(CleanupScheduleMode.SPECIFIC_DATETIME)
                .scheduledRunAt(null)
                .dayOfMonth(1)
                .dayOfWeek(1)
                .timeOfDay("02:00")
                .unreferencedUploadTtlHours(properties.getUnreferencedUploadTtlHours())
                .deletedMessageMediaTtlDays(properties.getDeletedMessageMediaTtlDays())
                .closedRepairMediaTtlDays(properties.getClosedRepairMediaTtlDays())
                .build();
    }
}

