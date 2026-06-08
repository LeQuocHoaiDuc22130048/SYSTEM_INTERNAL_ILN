package com.suachuabientan.system_internal.modules.messaging.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import com.suachuabientan.system_internal.modules.messaging.enums.ConversationType;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "conversations")
@Getter @Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Conversation extends BaseEntity {
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private ConversationType type;

    /** Tên nhóm - null với direct*/
    @Column(length = 100)
    private String name;

    @Column(name = "avatar_url", length = 500)
    private String avatarUrl;

    @Column(name = "pinned_message_id")
    private UUID pinnedMessageId;

    @Column(name = "pinned_message_at")
    private Instant pinnedMessageAt;

    @Column(name = "pinned_message_by")
    private UUID pinnedMessageBy;

}
