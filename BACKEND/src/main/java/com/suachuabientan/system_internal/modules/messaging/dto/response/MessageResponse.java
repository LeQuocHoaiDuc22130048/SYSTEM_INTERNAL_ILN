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
        Instant editedAt,
        Instant deletedForEveryoneAt,
        List<UUID> readByUserIds,
        List<UUID> mentionUserIds,
        List<ReactionInfo> reactions,
        UUID parentMessageId,
        ParentMessageInfo parentMessage
) {
    public record ParentMessageInfo(
            UUID id,
            String senderName,
            String content,
            String messageType,
            Instant deletedForEveryoneAt
    ) {
    }

    public String contentPreview() {
        if (content != null && !content.isBlank()) {
            return content.length() <= 120 ? content : content.substring(0, 117) + "...";
        }
        return switch (messageType) {
            case "IMAGE" -> "Đã gửi một hình ảnh";
            case "VIDEO" -> "Đã gửi một video";
            case "FILE" -> "Đã gửi một tệp đính kèm";
            default -> "Tin nhắn mới";
        };
    }

    public record SenderInfo(
            UUID id,
            String fullName,
            String avatarUrl
    ) {
    }

    public record ReactionInfo(
            String emoji,
            long count,
            List<UUID> userIds
    ) {
    }
}
