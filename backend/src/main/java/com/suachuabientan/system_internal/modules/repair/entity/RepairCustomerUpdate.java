package com.suachuabientan.system_internal.modules.repair.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "repair_customer_updates")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RepairCustomerUpdate extends BaseEntity {

    @Column(name = "order_id", nullable = false)
    private UUID orderId;

    @Column(name = "device_id")
    private UUID deviceId;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String message;

    @Column(name = "status_at_time", length = 20)
    private String statusAtTime;

    @Column(name = "published_by", nullable = false)
    private UUID publishedBy;

    @Column(name = "published_at", nullable = false)
    @Builder.Default
    private Instant publishedAt = Instant.now();
}
