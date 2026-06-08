package com.suachuabientan.system_internal.modules.messaging.repository;

import com.suachuabientan.system_internal.modules.messaging.entity.MessageMention;
import com.suachuabientan.system_internal.modules.messaging.entity.MessageMentionId;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface MessageMentionRepository extends JpaRepository<MessageMention, MessageMentionId> {
    List<MessageMention> findByMessageId(UUID messageId);

    List<MessageMention> findByMessageIdIn(List<UUID> messageIds);

    void deleteByMessageId(UUID messageId);
}
