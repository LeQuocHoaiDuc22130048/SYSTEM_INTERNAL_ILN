package com.suachuabientan.system_internal.modules.messaging.entity;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

public class MessageReactionId implements Serializable {
    private UUID messageId;
    private UUID userId;
    private String emoji;

    public MessageReactionId() {
    }

    public MessageReactionId(UUID messageId, UUID userId, String emoji) {
        this.messageId = messageId;
        this.userId = userId;
        this.emoji = emoji;
    }

    @Override
    public boolean equals(Object object) {
        if (!(object instanceof MessageReactionId that)) {
            return false;
        }
        return Objects.equals(messageId, that.messageId)
                && Objects.equals(userId, that.userId)
                && Objects.equals(emoji, that.emoji);
    }

    @Override
    public int hashCode() {
        return Objects.hash(messageId, userId, emoji);
    }
}
