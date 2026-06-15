package com.suachuabientan.system_internal.modules.warehouse.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "part_lots")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PartLot extends BaseEntity {
    @Column(name = "part_id", nullable = false)
    private UUID partId;

    @Column(name = "store_location_id")
    private UUID storeLocationId;

    @Column(nullable = false, precision = 18, scale = 4)
    @Builder.Default
    private BigDecimal amount = BigDecimal.ZERO;

    @Column(name = "instock_unknown", nullable = false)
    @Builder.Default
    private Boolean instockUnknown = false;

    @Column(name = "lot_code", unique = true, length = 100)
    private String lotCode;

    @Column(name = "needs_refill", nullable = false)
    @Builder.Default
    private Boolean needsRefill = false;

    @Column(name = "expiration_date")
    private LocalDate expirationDate;
}
