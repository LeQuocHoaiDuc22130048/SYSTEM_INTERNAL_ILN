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

import java.util.UUID;

@Entity
@Table(name = "store_locations")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StoreLocation extends BaseEntity {
    @Column(name = "parent_id")
    private UUID parentId;

    @Column(nullable = false, unique = true, length = 80)
    private String code;

    @Column(nullable = false, length = 200)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "is_full", nullable = false)
    @Builder.Default
    private Boolean isFull = false;

    @Column(name = "only_single_part", nullable = false)
    @Builder.Default
    private Boolean onlySinglePart = false;

    @Column(name = "qr_code", columnDefinition = "TEXT")
    private String qrCode;
}

