package com.suachuabientan.system_internal.modules.customer.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.UUID;

@Entity
@Table(name = "customer_accounts")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CustomerAccount extends BaseEntity {

    @Column(name = "user_id", nullable = false, unique = true)
    private UUID userId;

    @Column(name = "customer_id", nullable = false)
    private UUID customerId;

    @Column(name = "contact_name", nullable = false, length = 100)
    private String contactName;

    @Column(length = 20)
    private String phone;

    @Column(length = 254)
    private String email;

    @Column(name = "is_primary", nullable = false)
    @Builder.Default
    private boolean isPrimary = true;

    @Column(name = "must_change_password", nullable = false)
    @Builder.Default
    private boolean mustChangePassword = false;

    @Column(nullable = false)
    @Builder.Default
    private boolean active = true;
}
