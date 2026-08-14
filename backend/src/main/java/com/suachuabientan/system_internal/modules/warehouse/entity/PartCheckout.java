package com.suachuabientan.system_internal.modules.warehouse.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import com.suachuabientan.system_internal.modules.warehouse.enums.CheckoutStatus;
import com.suachuabientan.system_internal.modules.warehouse.enums.PartCondition;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "part_checkouts")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PartCheckout extends BaseEntity {

    @Column(name = "part_id", nullable = false)
    private UUID partId;

    @Column(name = "part_lot_id")
    private UUID partLotId;

    @Column(name = "store_location_id")
    private UUID storeLocationId;

    @Column(name = "taken_by", nullable = false)
    private UUID takenBy;

    @Column(name = "quantity", nullable = false, precision = 18, scale = 4)
    @Builder.Default
    private BigDecimal quantity = BigDecimal.ONE;

    @Column(name = "returned_quantity", precision = 18, scale = 4)
    @Builder.Default
    private BigDecimal returnedQuantity = BigDecimal.ZERO;

    @Column(name = "taken_at", nullable = false)
    private Instant takenAt;

    @Column(name = "returned_at")
    private Instant returnedAt;

    @Column(columnDefinition = "TEXT")
    private String purpose;

    @Column(name = "repair_order_id")
    private UUID repairOrderId;

    @Enumerated(EnumType.STRING)
    @Column(name = "condition_status", length = 30)
    private PartCondition conditionStatus;

    @Enumerated(EnumType.STRING)
    @Column(name = "checkout_status", nullable = false, length = 20)
    @Builder.Default
    private CheckoutStatus checkoutStatus = CheckoutStatus.OPEN;

    @Column(columnDefinition = "TEXT")
    private String notes;

    public boolean isReturned() {
        return this.returnedAt != null || CheckoutStatus.RETURNED.equals(this.checkoutStatus);
    }

    public boolean isActive() {
        return CheckoutStatus.OPEN.equals(this.checkoutStatus)
                && !Boolean.TRUE.equals(this.getIsDeleted());
    }
}
