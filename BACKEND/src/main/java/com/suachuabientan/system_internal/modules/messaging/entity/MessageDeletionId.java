package com.suachuabientan.system_internal.modules.messaging.entity;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

public class MessageDeletionId implements Serializable {
    private UUID messageId;
    private UUID userId;

    public MessageDeletionId() {
    }

    public MessageDeletionId(UUID messageId, UUID userId) {
        this.messageId = messageId;
        this.userId = userId;
    }

    @Override
    public boolean equals(Object object) {
        if (!(object instanceof MessageDeletionId that)) {
            return false;
        }
        return Objects.equals(messageId, that.messageId)
                && Objects.equals(userId, that.userId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(messageId, userId);
    }
}
