package com.suachuabientan.system_internal.modules.warehouse.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import com.suachuabientan.system_internal.modules.warehouse.enums.BoardStatus;
import jakarta.persistence.*;
import lombok.*;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.util.UUID;

@Entity
@Table(name = "board_items")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BoardItem extends BaseEntity {

    @Column(name = "qr_code", nullable = false, unique = true, length = 100)
    private String qrCode;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String name;

    @Column(length = 255)
    private String category;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private BoardStatus status = BoardStatus.AVAILABLE;

    @Column(length = 255)
    private String location;

    @Column(name = "quantity", nullable = false)
    @Builder.Default
    private Integer quantity = 1;

    @Column(name = "serial_number", unique = true, length = 100)
    private String serialNumber;

    @Column(length = 100)
    private String model;

    @Column(name = "repair_brand", length = 100)
    private String repairBrand;

    @Column(name = "board_type", length = 100)
    private String boardType;

    @Column(length = 50)
    private String firmware;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "removed_parts", columnDefinition = "JSONB")
    private String removedParts;

    @Column(name = "received_date")
    private java.time.LocalDate receivedDate;

    @Column(columnDefinition = "TEXT")
    private String note;

    @Column(name = "part_id")
    private UUID partId;

    @Column(name = "current_location_id")
    private UUID currentLocationId;

    public boolean isAvailable() {
        return BoardStatus.AVAILABLE.equals(this.status) && !Boolean.TRUE.equals(this.getIsDeleted());
    }

    public boolean hasStock() {
        return this.quantity != null && this.quantity > 0;
    }

    public boolean isCheckedOut() {
        return BoardStatus.CHECKED_OUT.equals(this.status);
    }
}
