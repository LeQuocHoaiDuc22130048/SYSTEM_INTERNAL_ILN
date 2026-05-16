package com.suachuabientan.system_internal.modules.messaging.repository;

import com.suachuabientan.system_internal.modules.messaging.entity.MessageRead;
import com.suachuabientan.system_internal.modules.messaging.entity.MessageReadId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface MessageReadRepository extends JpaRepository<MessageRead, MessageReadId> {
    /** Danh sách user đã đọc tin nhắn — hiện seen indicator */
    List<MessageRead> findByMessageId(UUID messageId);

    /** Kiểm tra user đã đọc tin nhắn chưa */
    boolean existsByMessageIdAndUserId(UUID messageId, UUID userId);

    /** Danh sách messageId user đã đọc trong conversation */
    @Query("""
            SELECT mr.messageId FROM MessageRead mr
            WHERE mr.userId = :userId
              AND mr.messageId IN :messageIds
            """)
    List<UUID> findReadMessageIds(

            @Param("userId") UUID userId,
            @Param("messageIds") List<UUID> messageIds);
}
