package com.suachuabientan.system_internal.modules.notification.service;

import com.google.auth.oauth2.GoogleCredentials;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.client.RestTemplate;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class FcmService {
    private static final String FCM_LEGACY_ENDPOINT = "https://fcm.googleapis.com/fcm/send";
    private static final String FCM_V1_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

    private final RestTemplate restTemplate;

    @Value("${app.firebase.project-id:}")
    private String projectId;

    @Value("${app.firebase.service-account-json:}")
    private String serviceAccountJson;

    @Value("${app.firebase.service-account-base64:}")
    private String serviceAccountBase64;

    @Value("${app.firebase.server-key:}")
    private String serverKey;

    public void send(
            String deviceToken,
            String title,
            String body,
            NotificationType type,
            String refType,
            String refId) {
        if (!StringUtils.hasText(deviceToken)) {
            return;
        }

        if (StringUtils.hasText(projectId) && hasServiceAccount()) {
            sendHttpV1(deviceToken, title, body, type, refType, refId);
            return;
        }

        sendLegacy(deviceToken, title, body, type, refType, refId);
    }

    private void sendHttpV1(
            String deviceToken,
            String title,
            String body,
            NotificationType type,
            String refType,
            String refId) {
        try {
            GoogleCredentials credentials = GoogleCredentials
                    .fromStream(new ByteArrayInputStream(serviceAccountBytes()))
                    .createScoped(List.of(FCM_V1_SCOPE));
            credentials.refreshIfExpired();

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBearerAuth(credentials.getAccessToken().getTokenValue());

            Map<String, Object> message = new HashMap<>();
            message.put("token", deviceToken);
            message.put("notification", Map.of("title", title, "body", body));
            message.put("data", buildData(type, refType, refId));
            message.put("android", Map.of("priority", "HIGH"));
            message.put("apns", Map.of("headers", Map.of("apns-priority", "10")));

            restTemplate.exchange(
                    "https://fcm.googleapis.com/v1/projects/" + projectId + "/messages:send",
                    HttpMethod.POST,
                    new HttpEntity<>(Map.of("message", message), headers),
                    String.class);
        } catch (Exception ex) {
            log.warn("Cannot send FCM HTTP v1 notification: {}", ex.getMessage());
        }
    }

    private void sendLegacy(
            String deviceToken,
            String title,
            String body,
            NotificationType type,
            String refType,
            String refId) {
        if (!StringUtils.hasText(serverKey)) {
            log.debug("Skip FCM because Firebase credentials are empty");
            return;
        }

        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.set("Authorization", "key=" + serverKey);

            Map<String, Object> payload = new HashMap<>();
            payload.put("to", deviceToken);
            payload.put("priority", "high");
            payload.put("notification", Map.of("title", title, "body", body));
            payload.put("data", buildData(type, refType, refId));

            restTemplate.exchange(
                    FCM_LEGACY_ENDPOINT,
                    HttpMethod.POST,
                    new HttpEntity<>(payload, headers),
                    String.class);
        } catch (Exception ex) {
            log.warn("Cannot send FCM legacy notification: {}", ex.getMessage());
        }
    }

    private Map<String, String> buildData(NotificationType type, String refType, String refId) {
        Map<String, String> data = new HashMap<>();
        data.put("type", type.name());
        if (StringUtils.hasText(refType)) {
            data.put("refType", refType);
        }
        if (StringUtils.hasText(refId)) {
            data.put("refId", refId);
        }
        return data;
    }

    private boolean hasServiceAccount() {
        return StringUtils.hasText(serviceAccountJson) || StringUtils.hasText(serviceAccountBase64);
    }

    private byte[] serviceAccountBytes() {
        if (StringUtils.hasText(serviceAccountBase64)) {
            return Base64.getDecoder().decode(serviceAccountBase64);
        }
        return serviceAccountJson.getBytes(StandardCharsets.UTF_8);
    }
}
