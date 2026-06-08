package com.suachuabientan.system_internal.modules.attendance.service;

import com.suachuabientan.system_internal.modules.attendance.dto.request.FaceRecognitionLogBatchRequest;
import com.suachuabientan.system_internal.modules.attendance.dto.request.FaceRecognitionLogItemRequest;
import com.suachuabientan.system_internal.modules.attendance.entity.FaceRecognitionDailyAlert;
import com.suachuabientan.system_internal.modules.attendance.entity.FaceRecognitionLog;
import com.suachuabientan.system_internal.modules.attendance.repository.FaceRecognitionDailyAlertRepository;
import com.suachuabientan.system_internal.modules.attendance.repository.FaceRecognitionLogRepository;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class FaceRecognitionMonitoringService {
    private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Ho_Chi_Minh");
    private static final String SOURCE_MOBILE_OFFLINE = "MOBILE_OFFLINE";
    private static final String SOURCE_SERVER_ONLINE = "SERVER_ONLINE";
    private static final String SOURCE_SERVER_SYNC = "SERVER_SYNC";

    private final FaceRecognitionLogRepository logRepository;
    private final FaceRecognitionDailyAlertRepository alertRepository;
    private final NotificationService notificationService;

    @Value("${app.attendance.face.frr-alert-threshold:${ATTENDANCE_FACE_FRR_ALERT_THRESHOLD:0.05}}")
    private double frrAlertThreshold;

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public int saveMobileLogs(FaceRecognitionLogBatchRequest request, UUID syncedBy) {
        int saved = 0;
        for (FaceRecognitionLogItemRequest item : request.logs()) {
            if (StringUtils.hasText(item.localAttemptId())
                    && logRepository
                    .findByLocalAttemptIdAndSourceAndIsDeletedFalse(item.localAttemptId(), SOURCE_MOBILE_OFFLINE)
                    .isPresent()) {
                continue;
            }
            logRepository.save(FaceRecognitionLog.builder()
                    .localAttemptId(item.localAttemptId())
                    .employeeId(item.employeeId())
                    .employeeName(item.employeeName())
                    .attemptedBy(syncedBy)
                    .deviceId(item.deviceId())
                    .modelName(item.modelName())
                    .source(SOURCE_MOBILE_OFFLINE)
                    .outcome(normalizeOutcome(item.outcome()))
                    .similarityScore(item.similarityScore())
                    .threshold(item.threshold())
                    .occurredAt(item.occurredAt())
                    .build());
            saved++;
        }
        evaluateAndAlert(LocalDate.now(BUSINESS_ZONE));
        return saved;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordServerOnlineAttempt(
            UUID employeeId,
            String employeeName,
            UUID attemptedBy,
            String deviceId,
            String modelName,
            boolean matched,
            double similarityScore,
            double threshold) {
        recordServerAttempt(
                employeeId,
                employeeName,
                attemptedBy,
                deviceId,
                modelName,
                matched,
                similarityScore,
                threshold,
                SOURCE_SERVER_ONLINE);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordServerSyncAttempt(
            UUID employeeId,
            String employeeName,
            UUID attemptedBy,
            String deviceId,
            String modelName,
            boolean matched,
            double similarityScore,
            double threshold) {
        recordServerAttempt(
                employeeId,
                employeeName,
                attemptedBy,
                deviceId,
                modelName,
                matched,
                similarityScore,
                threshold,
                SOURCE_SERVER_SYNC);
    }

    @Scheduled(cron = "${app.attendance.face.frr-monitor-cron:0 5 0 * * *}", zone = "Asia/Ho_Chi_Minh")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void evaluateYesterday() {
        evaluateAndAlert(LocalDate.now(BUSINESS_ZONE).minusDays(1));
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void evaluateAndAlert(LocalDate date) {
        Instant from = date.atStartOfDay(BUSINESS_ZONE).toInstant();
        Instant to = date.plusDays(1).atStartOfDay(BUSINESS_ZONE).toInstant();
        long total = logRepository.countAttemptsWithCandidate(from, to);
        if (total == 0) return;

        long rejected = logRepository.countRejectedWithCandidate(from, to);
        double frr = rejected / (double) total;
        if (frr <= frrAlertThreshold) return;
        if (alertRepository.findByMetricDateAndIsDeletedFalse(date).isPresent()) return;

        alertRepository.save(FaceRecognitionDailyAlert.builder()
                .metricDate(date)
                .falseRejectRate(frr)
                .rejectedCount(rejected)
                .totalCount(total)
                .build());
        notificationService.sendToRoles(
                List.of(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.MANAGER),
                NotificationType.ATTENDANCE_FACE_FRR_ALERT,
                "Can kiem tra nhan dien khuon mat",
                "Ty le reject khuon mat ngay "
                        + date
                        + " vuot "
                        + percent(frrAlertThreshold)
                        + ": "
                        + percent(frr)
                        + " ("
                        + rejected
                        + "/"
                        + total
                        + "). Thuong xay ra khi nhan vien doi kieu toc, deo kinh hoac thay doi ngoai hinh.",
                "ATTENDANCE_FACE_FRR",
                date.toString(),
                true);
        log.warn("Face recognition reject-rate alert: date={}, frr={}, rejected={}, total={}",
                date, frr, rejected, total);
    }

    private void recordServerAttempt(
            UUID employeeId,
            String employeeName,
            UUID attemptedBy,
            String deviceId,
            String modelName,
            boolean matched,
            double similarityScore,
            double threshold,
            String source) {
        logRepository.save(FaceRecognitionLog.builder()
                .employeeId(employeeId)
                .employeeName(employeeName)
                .attemptedBy(attemptedBy)
                .deviceId(deviceId)
                .modelName(modelName)
                .source(source)
                .outcome(matched ? "MATCHED" : "REJECTED")
                .similarityScore(similarityScore)
                .threshold(threshold)
                .occurredAt(Instant.now())
                .build());
        evaluateAndAlert(LocalDate.now(BUSINESS_ZONE));
    }

    private String normalizeOutcome(String outcome) {
        String normalized = outcome == null ? "REJECTED" : outcome.trim().toUpperCase(Locale.ROOT);
        return "MATCHED".equals(normalized) ? "MATCHED" : "REJECTED";
    }

    private String percent(double value) {
        return String.format(Locale.US, "%.2f%%", value * 100);
    }
}
