package com.suachuabientan.system_internal.modules.notification.dto.response;

import java.time.Instant;
import java.util.UUID;

public record NotificationResponse(
        UUID id,
        UUID recipientId,
        String type,
        String title,
        String body,
        String refType,
        String refId,
        Boolean isRead,
        Instant createdAt
) {
}
