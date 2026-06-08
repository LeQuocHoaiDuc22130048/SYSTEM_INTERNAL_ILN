package com.suachuabientan.system_internal.modules.messaging.repository;

import com.suachuabientan.system_internal.modules.messaging.entity.Conversation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ConversationRepository extends JpaRepository<Conversation, UUID> {
    Optional<Conversation> findByIdAndIsDeletedFalse(UUID id);

    /**
     * Danh sách conversation của user — sort theo tin nhắn mới nhất.
     */
    @Query(value = """
                     SELECT c.* FROM conversations c
                                INNER JOIN conversation_members cm ON c.id = cm.conversation_id
                                WHERE cm.user_id = :userId
                                  AND c.is_deleted = false
                                ORDER BY cm.pinned_at DESC NULLS LAST, c.updated_at DESC
            """, nativeQuery = true)
    List<Conversation> findByMember(@Param("userId") UUID userId);

    /**
     * Tìm conversation DIRECT giữa 2 user.
     * Dùng để kiểm tra tránh tạo duplicate.
     */
    @Query(value = """
            SELECT c.* FROM conversations c
            INNER JOIN conversation_members cm1 ON c.id = cm1.conversation_id AND cm1.user_id = :userId1
            INNER JOIN conversation_members cm2 ON c.id = cm2.conversation_id AND cm2.user_id = :userId2
            WHERE c.type = 'DIRECT' AND c.is_deleted = false
            LIMIT 1
            """, nativeQuery = true)
    Optional<Conversation> findDirectConversation(
            @Param("userId1") UUID userId1,
            @Param("userId2") UUID userId2);
}
