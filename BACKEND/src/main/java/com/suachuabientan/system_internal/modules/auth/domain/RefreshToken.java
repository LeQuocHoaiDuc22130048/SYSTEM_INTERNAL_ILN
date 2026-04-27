package com.suachuabientan.system_internal.modules.auth.domain;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import lombok.experimental.FieldDefaults;

import java.time.LocalDateTime;

@Entity
@Table(name = "refresh_tokens", indexes = {
    @Index(name = "idx_token", columnList = "token"),
    @Index(name = "idx_user_id", columnList = "user_id"),
    @Index(name = "idx_expiry_date", columnList = "expiryDate")
})
@FieldDefaults(level = lombok.AccessLevel.PRIVATE)
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RefreshToken extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    Long id;

    @Column(nullable = false, unique = true)
    String token;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    UserEntity user;

    @Column(nullable = false)
    LocalDateTime expiryDate;

    @Builder.Default
    @Column(nullable = false)
    boolean revoked = false;

    @Builder.Default
    @Column(nullable = false)
    boolean expired = false;
}