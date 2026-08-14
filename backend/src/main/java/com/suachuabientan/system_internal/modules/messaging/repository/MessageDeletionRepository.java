package com.suachuabientan.system_internal.modules.messaging.repository;

import com.suachuabientan.system_internal.modules.messaging.entity.MessageDeletion;
import com.suachuabientan.system_internal.modules.messaging.entity.MessageDeletionId;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface MessageDeletionRepository extends JpaRepository<MessageDeletion, MessageDeletionId> {
    boolean existsByMessageIdAndUserId(UUID messageId, UUID userId);

    List<MessageDeletion> findByUserIdAndMessageIdIn(UUID userId, List<UUID> messageIds);
}
