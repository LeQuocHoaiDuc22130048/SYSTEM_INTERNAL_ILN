package com.suachuabientan.system_internal.modules.warehouse.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import com.suachuabientan.system_internal.modules.warehouse.enums.CheckoutStatus;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "board_checkouts")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BoardCheckout extends BaseEntity {

    @Column(name = "board_item_id", nullable = false)
    private UUID boardItemId;

    // Nhân viên lấy bo mạch
    @Column(name = "taken_by", nullable = false)
    private UUID takenBy;

    /**
     * Đơn sữa chữa liên quan
     * Nhân viên lấy trước khi tạo đơn
     * */
    @Column(name = "repair_order_id")
    private UUID repairOrderId;

    @Column(name = "taken_at", nullable = false)
    private Instant takenAt;

    /*
    * NULL chưa trả về
    * */
    @Column(name = "returned_at")
    private Instant returnedAt;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Enumerated(EnumType.STRING)
    @Column(name = "checkout_status", nullable = false, length = 20)
    @Builder.Default
    private CheckoutStatus checkoutStatus = CheckoutStatus.OPEN;

    public boolean isReturned() {
        return this.returnedAt != null;
    }

    public boolean isActive() {
        return CheckoutStatus.OPEN.equals(this.checkoutStatus)
                && this.returnedAt == null
                && !Boolean.TRUE.equals(this.getIsDeleted());
    }
}
