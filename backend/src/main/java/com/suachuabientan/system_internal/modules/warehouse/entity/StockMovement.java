package com.suachuabientan.system_internal.modules.warehouse.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import com.suachuabientan.system_internal.modules.warehouse.enums.StockMovementType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "stock_movements")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StockMovement extends BaseEntity {
    @Column(name = "movement_code", unique = true, length = 50)
    private String movementCode;

    @Column(name = "part_id")
    private UUID partId;

    @Column(name = "part_lot_id")
    private UUID partLotId;

    @Column(name = "board_item_id")
    private UUID boardItemId;

    @Column(name = "storage_location_id")
    private UUID storageLocationId;

    @Enumerated(EnumType.STRING)
    @Column(name = "movement_type", nullable = false, length = 30)
    private StockMovementType movementType;

    @Column(nullable = false, precision = 18, scale = 4)
    @Builder.Default
    private BigDecimal quantity = BigDecimal.ONE;

    @Column(precision = 18, scale = 4)
    @Builder.Default
    private BigDecimal amount = BigDecimal.ZERO;

    @Column(name = "remaining_to_return", precision = 18, scale = 4)
    @Builder.Default
    private BigDecimal remainingToReturn = BigDecimal.ZERO;

    @Column(name = "movement_status", length = 20)
    @Builder.Default
    private String movementStatus = "COMPLETED";

    @Column(name = "parent_movement_id")
    private UUID parentMovementId;

    @Column(name = "from_location_id")
    private UUID fromLocationId;

    @Column(name = "to_location_id")
    private UUID toLocationId;

    @Column(name = "ref_type", length = 50)
    private String refType;

    @Column(name = "ref_id")
    private UUID refId;

    @Column(columnDefinition = "TEXT")
    private String purpose;

    @Column(columnDefinition = "TEXT")
    private String note;
}
