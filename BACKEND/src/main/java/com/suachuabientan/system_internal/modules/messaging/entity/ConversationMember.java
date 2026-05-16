package com.suachuabientan.system_internal.modules.messaging.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "conversation_members")
@Getter @Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@IdClass(ConversationMemberId.class)
public class ConversationMember {

    @Id
    @Column(name = "conversation_id", nullable = false)
    private UUID conversationId;

    @Id
    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "joined_at", nullable = false)
    private Instant joinAt;

    // Thời điểm đọc tin nhắn cuối - dùng để đếm unread
    @Column(name = "last_read_at")
    private Instant lastReadAt;

    // Admin của nhóm có quyền thêm/bớt thành viên
    @Column(name = "is_admin", nullable = false)
    private Boolean isAdmin = false;
}
