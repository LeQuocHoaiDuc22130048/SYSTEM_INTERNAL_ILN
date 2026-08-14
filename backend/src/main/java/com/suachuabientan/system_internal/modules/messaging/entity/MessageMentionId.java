package com.suachuabientan.system_internal.modules.messaging.entity;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

public class MessageMentionId implements Serializable {
    private UUID messageId;
    private UUID mentionedUserId;

    public MessageMentionId() {
    }

    public MessageMentionId(UUID messageId, UUID mentionedUserId) {
        this.messageId = messageId;
        this.mentionedUserId = mentionedUserId;
    }

    @Override
    public boolean equals(Object object) {
        if (!(object instanceof MessageMentionId that)) {
            return false;
        }
        return Objects.equals(messageId, that.messageId)
                && Objects.equals(mentionedUserId, that.mentionedUserId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(messageId, mentionedUserId);
    }
}
