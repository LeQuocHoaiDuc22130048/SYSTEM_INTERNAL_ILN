package com.suachuabientan.system_internal.modules.warehouse.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import com.suachuabientan.system_internal.modules.warehouse.enums.BoardStatus;
import jakarta.persistence.*;
import lombok.*;

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

    @Column(nullable = false, length = 200)
    private String name;

    @Column(length = 100)
    private String category;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private BoardStatus status = BoardStatus.AVAILABLE;

    @Column(length = 100)
    private String location;

    public boolean isAvailable() {
        return BoardStatus.AVAILABLE.equals(this.status) && !Boolean.TRUE.equals(this.getIsDeleted());
    }

    public boolean isCheckedOut() {
        return BoardStatus.CHECKED_OUT.equals(this.status);
    }
}
