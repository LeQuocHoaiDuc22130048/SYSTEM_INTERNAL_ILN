package com.suachuabientan.system_internal.modules.messaging.repository;

import com.suachuabientan.system_internal.modules.messaging.entity.ConversationMember;
import com.suachuabientan.system_internal.modules.messaging.entity.ConversationMemberId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ConversationMemberRepository extends JpaRepository<ConversationMember, ConversationMemberId> {
    List<ConversationMember> findByConversationId(UUID conversationId);

    Optional<ConversationMember> findByConversationIdAndUserId(UUID conversationId, UUID userId);

    boolean existsByConversationIdAndUserId(UUID conversationId, UUID userId);

    void deleteByConversationIdAndUserId(UUID conversationId, UUID userId);

    /**
     * Cập nhật last_read_at khi user đọc tin nhắn.
     */
    @Modifying
    @Query("""
            UPDATE ConversationMember cm
            SET cm.lastReadAt = :readAt
            WHERE cm.conversationId = :conversationId
              AND cm.userId = :userId
            """)
    void updateLastReadAt(
            @Param("conversationId") UUID conversationId,
            @Param("userId") UUID userId,
            @Param("readAt") Instant readAt);
}
