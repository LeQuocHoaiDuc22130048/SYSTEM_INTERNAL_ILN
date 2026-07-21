package com.suachuabientan.system_internal.modules.warehouse.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import com.suachuabientan.system_internal.modules.warehouse.enums.BoardStatus;
import jakarta.persistence.*;
import lombok.*;

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

    @Column(name = "serial_number", unique = true, length = 100)
    private String serialNumber;

    @Column(name = "part_id")
    private UUID partId;

    @Column(name = "current_location_id")
    private UUID currentLocationId;

    public boolean isAvailable() {
        return BoardStatus.AVAILABLE.equals(this.status) && !Boolean.TRUE.equals(this.getIsDeleted());
    }

    public boolean isCheckedOut() {
        return BoardStatus.CHECKED_OUT.equals(this.status);
    }
}
