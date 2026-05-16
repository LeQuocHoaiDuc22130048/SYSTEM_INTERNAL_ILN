package com.suachuabientan.system_internal.modules.messaging.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "message_reads")
@Getter @Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@IdClass(MessageReadId.class)
public class MessageRead {

    @Id
    @Column(name = "message_id", nullable = false)
    private UUID messageId;

    @Id
    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "read_at", nullable = false)
    private Instant readAt;
}
