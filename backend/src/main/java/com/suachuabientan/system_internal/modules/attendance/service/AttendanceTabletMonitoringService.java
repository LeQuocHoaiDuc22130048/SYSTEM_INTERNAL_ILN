package com.suachuabientan.system_internal.modules.attendance.service;

import com.suachuabientan.system_internal.modules.attendance.tablet.TabletDevice;
import com.suachuabientan.system_internal.modules.attendance.tablet.TabletDeviceRepository;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Giám sát trạng thái kết nối của các thiết bị tablet chấm công.
 * Tự động phát hiện khi thiết bị mất nhịp tim (heartbeat) vượt quá ngưỡng thời gian quy định
 * và phát thông báo cảnh báo đến website & ứng dụng di động của Ban Quản trị (Admin).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AttendanceTabletMonitoringService {

    private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Ho_Chi_Minh");
    private static final DateTimeFormatter TIME_FORMATTER = DateTimeFormatter.ofPattern("HH:mm:ss dd/MM/yyyy", Locale.getDefault());

    private final TabletDeviceRepository tabletDeviceRepository;
    private final NotificationService notificationService;

    // Lưu trữ các tablet đã gửi cảnh báo mất kết nối để tránh gửi lặp thông báo liên tục
    private final Set<UUID> alertedDisconnectedTablets = ConcurrentHashMap.newKeySet();

    @Value("${app.attendance.tablets.disconnect-threshold-seconds:180}")
    private long disconnectThresholdSeconds;

    /**
     * Chạy định kỳ để quét trạng thái nhịp tim của toàn bộ máy chấm công đã được phê duyệt.
     */
    @Scheduled(fixedDelayString = "${app.attendance.tablets.monitor-interval-ms:30000}", initialDelay = 15000)
    public void monitorAttendanceTablets() {
        List<TabletDevice> approvedTablets = tabletDeviceRepository.findAll().stream()
                .filter(t -> "APPROVED".equalsIgnoreCase(t.getStatus()))
                .toList();

        if (approvedTablets.isEmpty()) {
            return;
        }

        Instant now = Instant.now();
        Instant cutoffTime = now.minusSeconds(disconnectThresholdSeconds);

        for (TabletDevice tablet : approvedTablets) {
            Instant lastSeen = tablet.getLastSeenAt();
            boolean isDisconnected = (lastSeen == null) || lastSeen.isBefore(cutoffTime);

            if (isDisconnected) {
                // Nếu chưa từng gửi cảnh báo cho lần mất kết nối này
                if (alertedDisconnectedTablets.add(tablet.getId())) {
                    String timeStr = lastSeen != null
                            ? TIME_FORMATTER.format(lastSeen.atZone(BUSINESS_ZONE))
                            : "chưa có kết nối";
                    String modelStr = tablet.getModel() != null && !tablet.getModel().isBlank()
                            ? tablet.getModel()
                            : "Tablet";

                    String title = "Cảnh báo: Mất kết nối máy chấm công";
                    String body = String.format(
                            "Máy chấm công \"%s\" (%s) đã mất kết nối với hệ thống từ lúc %s. Vui lòng kiểm tra nguồn điện hoặc kết nối mạng Wi-Fi.",
                            tablet.getName(), modelStr, timeStr);

                    log.warn("Tablet chấm công '{}' (ID: {}) bị mất kết nối! Lần cuối nhìn thấy: {}",
                            tablet.getName(), tablet.getId(), timeStr);

                    try {
                        notificationService.sendToRoles(
                                List.of(UserRole.ADMIN, UserRole.SUPER_ADMIN),
                                NotificationType.ATTENDANCE_DEVICE_DISCONNECTED,
                                title,
                                body,
                                "ATTENDANCE_TABLET",
                                tablet.getId().toString(),
                                true // Gửi push notification FCM đến ứng dụng admin
                        );
                    } catch (Exception e) {
                        log.error("Lỗi khi gửi thông báo mất kết nối cho tablet {}: {}", tablet.getId(), e.getMessage());
                    }
                }
            } else {
                // Thiết bị đã có tín hiệu nhịp tim trở lại và trước đó từng bị cảnh báo mất kết nối
                if (alertedDisconnectedTablets.remove(tablet.getId())) {
                    String modelStr = tablet.getModel() != null && !tablet.getModel().isBlank()
                            ? tablet.getModel()
                            : "Tablet";
                    String title = "Thông báo: Máy chấm công đã kết nối lại";
                    String body = String.format(
                            "Máy chấm công \"%s\" (%s) đã khôi phục kết nối thành công với máy chủ.",
                            tablet.getName(), modelStr);

                    log.info("Tablet chấm công '{}' (ID: {}) đã kết nối lại thành công.",
                            tablet.getName(), tablet.getId());

                    try {
                        notificationService.sendToRoles(
                                List.of(UserRole.ADMIN, UserRole.SUPER_ADMIN),
                                NotificationType.ATTENDANCE_DEVICE_RECONNECTED,
                                title,
                                body,
                                "ATTENDANCE_TABLET",
                                tablet.getId().toString(),
                                true // Gửi push notification FCM đến ứng dụng admin
                        );
                    } catch (Exception e) {
                        log.error("Lỗi khi gửi thông báo kết nối lại cho tablet {}: {}", tablet.getId(), e.getMessage());
                    }
                }
            }
        }
    }

    /**
     * Ghi nhận tức thì khi máy chấm công gửi heartbeat thành công.
     * Nếu trước đó máy đang ở trạng thái mất kết nối, hệ thống sẽ gửi thông báo phục hồi ngay lập tức.
     */
    public void onHeartbeatReceived(UUID tabletId) {
        if (alertedDisconnectedTablets.remove(tabletId)) {
            tabletDeviceRepository.findById(tabletId).ifPresent(tablet -> {
                String modelStr = tablet.getModel() != null && !tablet.getModel().isBlank()
                        ? tablet.getModel()
                        : "Tablet";
                String title = "Thông báo: Máy chấm công đã kết nối lại";
                String body = String.format(
                        "Máy chấm công \"%s\" (%s) đã khôi phục kết nối thành công với máy chủ.",
                        tablet.getName(), modelStr);

                log.info("Tablet chấm công '{}' (ID: {}) đã kết nối lại thành công (qua heartbeat).",
                        tablet.getName(), tablet.getId());

                try {
                    notificationService.sendToRoles(
                            List.of(UserRole.ADMIN, UserRole.SUPER_ADMIN),
                            NotificationType.ATTENDANCE_DEVICE_RECONNECTED,
                            title,
                            body,
                            "ATTENDANCE_TABLET",
                            tablet.getId().toString(),
                            true
                    );
                } catch (Exception e) {
                    log.error("Lỗi khi gửi thông báo kết nối lại cho tablet {}: {}", tablet.getId(), e.getMessage());
                }
            });
        }
    }

    public boolean isTabletDisconnected(UUID tabletId) {
        return alertedDisconnectedTablets.contains(tabletId);
    }
}
