package com.suachuabientan.system_internal.modules.notification.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

@Entity
@Table(name = "notifications")
@Getter @Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Notification extends BaseEntity {
    @Column(name = "recipient_id", nullable = false)
    private UUID recipientId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 50)
    private NotificationType type;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String body;

    /**
     * Deep link — loại đối tượng liên quan.
     * VD: REPAIR_ORDER | BOARD_ITEM | USER
     */
    @Column(name = "ref_type", length = 50)
    private String refType;

    /**
     * Deep link — UUID của đối tượng liên quan.
     */
    @Column(name = "ref_id", length = 100)
    private String refId;

    @Column(name = "is_read", nullable = false)
    private Boolean isRead = false;
}
