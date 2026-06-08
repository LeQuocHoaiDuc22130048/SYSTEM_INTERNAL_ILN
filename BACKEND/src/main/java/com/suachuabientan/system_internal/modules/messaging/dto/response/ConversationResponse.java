package com.suachuabientan.system_internal.modules.messaging.dto.response;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record ConversationResponse(
        UUID id,
        String type,
        String name,
        String avatarUrl,
        List<MemberInfo> members,
        MessageInfo lastMessage,
        MessageInfo pinnedMessage,
        Boolean pinned,
        Instant pinnedAt,
        Boolean notificationsMuted,
        long unreadCount,
        Instant createdAt
) {
    public record MemberInfo(
            UUID userId,
            String fullName,
            String employeeCode,
            String avatarUrl,
            Boolean isAdmin,
            String role,
            Boolean canChat
    ) {
    }

    public record MessageInfo(
            UUID id,
            String senderName,
            String content,
            String messageType,
            Instant sentAt
    ) {
    }
}
