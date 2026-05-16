package com.suachuabientan.system_internal.modules.messaging.repository;

import com.suachuabientan.system_internal.modules.messaging.entity.Message;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface MessageRepository extends JpaRepository<Message, UUID> {
    Page<Message> findByConversationIdAndIsDeletedFalseOrderBySentAtDesc(UUID conversationId, Pageable pageable);

    Optional<Message> findFirstByConversationIdAndIsDeletedFalseOrderBySentAtDesc(UUID conversationId);

    @Query("""
            SELECT COUNT(m) FROM Message m
            WHERE m.conversationId = :conversationId
              AND m.senderId <> :userId
              AND m.isDeleted = false
              AND (:lastReadAt IS NULL OR m.sentAt > :lastReadAt)
            """)
    long countUnread(
            @Param("conversationId") UUID conversationId,
            @Param("userId") UUID userId,
            @Param("lastReadAt") Instant lastReadAt);

    @Query("""
            SELECT m.id FROM Message m
            WHERE m.conversationId = :conversationId
              AND m.senderId <> :userId
              AND m.isDeleted = false
              AND (:lastReadAt IS NULL OR m.sentAt > :lastReadAt)
            """)
    List<UUID> findUnreadMessageIds(
            @Param("conversationId") UUID conversationId,
            @Param("userId") UUID userId,
            @Param("lastReadAt") Instant lastReadAt);
}
