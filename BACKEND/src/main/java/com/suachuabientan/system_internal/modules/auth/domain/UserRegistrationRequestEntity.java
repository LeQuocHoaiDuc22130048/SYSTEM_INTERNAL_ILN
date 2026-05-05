package com.suachuabientan.system_internal.modules.auth.domain;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "user_registration_requests")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserRegistrationRequestEntity extends BaseEntity {

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "action", nullable = false, length = 20)
    private String action; // APPROVE | REJECT

    @Column(name = "reviewed_by", nullable = false)
    private UUID reviewedBy;

    @Column(name = "note", columnDefinition = "TEXT")
    private String note;

    @Column(name = "reviewed_at", nullable = false)
    private Instant reviewedAt;
}
