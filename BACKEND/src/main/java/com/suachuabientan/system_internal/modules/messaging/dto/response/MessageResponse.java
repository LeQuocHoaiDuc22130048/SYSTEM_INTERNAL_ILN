package com.suachuabientan.system_internal.modules.messaging.dto.response;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record MessageResponse(
        UUID id,
        UUID conversationId,
        SenderInfo sender,
        String content,
        String mediaUrl,
        String messageType,
        Instant sentAt,
        List<UUID> readByUserIds  // Seen indicator
) {
    public String contentPreview() {
        if (content != null && !content.isBlank()) {
            return content.length() <= 120 ? content : content.substring(0, 117) + "...";
        }
        return switch (messageType) {
            case "IMAGE" -> "Da gui mot hinh anh";
            case "FILE" -> "Da gui mot tep dinh kem";
            default -> "Tin nhan moi";
        };
    }

    public record SenderInfo(
            UUID id,
            String fullName,
            String avatarUrl
    ) {
    }
}
