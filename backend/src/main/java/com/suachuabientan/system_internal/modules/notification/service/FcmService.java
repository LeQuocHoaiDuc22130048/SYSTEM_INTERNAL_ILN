package com.suachuabientan.system_internal.modules.notification.service;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.*;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.Map;

@Slf4j
@Service
public class FcmService {
    /**
     * Gửi push notification đến một thiết bị.
     *
     * @param deviceToken  FCM registration token của thiết bị (từ Flutter)
     * @param title        Tiêu đề notification
     * @param body         Nội dung notification
     * @param data         Data payload — Flutter dùng để navigate đúng màn hình
     */
    public void sendToDevice(String deviceToken, String title, String body,
                             Map<String, String> data) {
        if (deviceToken == null || deviceToken.isBlank()) {
            log.debug("Bỏ qua push — deviceToken trống");
            return;
        }

        if (!isFirebaseReady()) {
            log.warn("Firebase chưa được cấu hình — bỏ qua push notification: title={}", title);
            return;
        }

        try {
            Message.Builder messageBuilder = Message.builder()
                    .setToken(deviceToken)
                    .setNotification(Notification.builder()
                            .setTitle(title)
                            .setBody(body)
                            .build())
                    // Android config
                    .setAndroidConfig(AndroidConfig.builder()
                            .setPriority(AndroidConfig.Priority.HIGH)
                            .setNotification(AndroidNotification.builder()
                                    .setSound("default")
                                    .setClickAction("FLUTTER_NOTIFICATION_CLICK")
                                    .setChannelId("system_internal_notifications")
                                    .build())
                            .build())
                    // iOS config
                    .setApnsConfig(ApnsConfig.builder()
                            .setAps(Aps.builder()
                                    .setSound("default")
                                    .setBadge(1)
                                    .build())
                            .build());

            // Thêm data payload nếu có
            if (data != null && !data.isEmpty()) {
                messageBuilder.putAllData(data);
            }

            String messageId = FirebaseMessaging.getInstance()
                    .send(messageBuilder.build());

            log.debug("Push notification gửi thành công: messageId={}, title={}", messageId, title);

        } catch (FirebaseMessagingException e) {
            handleFcmException(e, deviceToken);
        } catch (Exception e) {
            // Không throw — push thất bại không được ảnh hưởng nghiệp vụ
            log.error("Lỗi gửi push notification: {}", e.getMessage());
        }
    }

    /**
     * Gửi notification đến nhiều thiết bị cùng lúc (tối đa 500).
     */
    public void sendToMultipleDevices(java.util.List<String> deviceTokens,
                                      String title, String body,
                                      Map<String, String> data) {
        if (deviceTokens == null || deviceTokens.isEmpty()) return;
        if (!isFirebaseReady()) return;

        try {
            MulticastMessage.Builder builder = MulticastMessage.builder()
                    .addAllTokens(deviceTokens)
                    .setNotification(Notification.builder()
                            .setTitle(title)
                            .setBody(body)
                            .build())
                    .setAndroidConfig(AndroidConfig.builder()
                            .setPriority(AndroidConfig.Priority.HIGH)
                            .setNotification(AndroidNotification.builder()
                                    .setSound("default")
                                    .setClickAction("FLUTTER_NOTIFICATION_CLICK")
                                    .setChannelId("system_internal_notifications")
                                    .build())
                            .build());

            if (data != null && !data.isEmpty()) {
                builder.putAllData(data);
            }

            BatchResponse response = FirebaseMessaging.getInstance()
                    .sendEachForMulticast(builder.build());

            log.info("Multicast push: success={}, failure={}",
                    response.getSuccessCount(), response.getFailureCount());

        } catch (FirebaseMessagingException e) {
            log.error("Lỗi gửi multicast push: code={}, message={}",
                    e.getMessagingErrorCode(), e.getMessage());
        }
    }

    // ── Helpers ───────────────────────────────────────────────

    private boolean isFirebaseReady() {
        return !FirebaseApp.getApps().isEmpty();
    }

    /**
     * Xử lý lỗi FCM — log chi tiết, không throw.
     * Token không hợp lệ → cần xoá khỏi DB (gọi callback nếu cần).
     */
    private void handleFcmException(FirebaseMessagingException e, String deviceToken) {
        MessagingErrorCode code = e.getMessagingErrorCode();

        if (code == MessagingErrorCode.UNREGISTERED
                || code == MessagingErrorCode.INVALID_ARGUMENT) {
            // Token không còn hợp lệ — Flutter đã gỡ app hoặc đổi thiết bị
            log.warn("FCM token không hợp lệ, cần xoá: token={}...{}",
                    deviceToken.substring(0, Math.min(10, deviceToken.length())),
                    deviceToken.substring(Math.max(0, deviceToken.length() - 5)));
            // TODO: publish event để AuthService xoá device_token của user
        } else {
            log.error("FCM error: code={}, message={}", code, e.getMessage());
        }
    }
}
