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
            """)
    long countUnread(
            @Param("conversationId") UUID conversationId,
            @Param("userId") UUID userId);

    @Query("""
            SELECT COUNT(m) FROM Message m
            WHERE m.conversationId = :conversationId
              AND m.senderId <> :userId
              AND m.isDeleted = false
              AND m.sentAt > :lastReadAt
            """)
    long countUnreadAfter(
            @Param("conversationId") UUID conversationId,
            @Param("userId") UUID userId,
            @Param("lastReadAt") Instant lastReadAt);

    @Query("""
            SELECT m.id FROM Message m
            WHERE m.conversationId = :conversationId
              AND m.senderId <> :userId
              AND m.isDeleted = false
            """)
    List<UUID> findUnreadMessageIds(
            @Param("conversationId") UUID conversationId,
            @Param("userId") UUID userId);

    @Query("""
            SELECT m.id FROM Message m
            WHERE m.conversationId = :conversationId
              AND m.senderId <> :userId
              AND m.isDeleted = false
              AND m.sentAt > :lastReadAt
            """)
    List<UUID> findUnreadMessageIdsAfter(
            @Param("conversationId") UUID conversationId,
            @Param("userId") UUID userId,
            @Param("lastReadAt") Instant lastReadAt);
}
