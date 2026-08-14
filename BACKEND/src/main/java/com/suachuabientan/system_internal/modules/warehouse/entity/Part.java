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

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "parts")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Part extends BaseEntity {
    @Column(nullable = false, unique = true, length = 100)
    private String ipn;

    @Column(unique = true, length = 100)
    private String sku;

    @Column(nullable = false, length = 200)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(length = 100)
    private String series;

    @Column(length = 50)
    private String footprint;

    @Column(name = "measurement_unit", nullable = false, length = 20)
    @Builder.Default
    private String measurementUnit = "Cái";

    @Column(name = "min_amount", nullable = false, precision = 18, scale = 4)
    @Builder.Default
    private BigDecimal minAmount = BigDecimal.ZERO;

    @Column(name = "max_amount", precision = 18, scale = 4)
    @Builder.Default
    private BigDecimal maxAmount = BigDecimal.ZERO;

    @Column(name = "purchase_price", precision = 15, scale = 2)
    private BigDecimal purchasePrice;

    @Column(name = "sale_price", precision = 15, scale = 2)
    private BigDecimal salePrice;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "JSONB")
    private String parameters;

    @Column(name = "replacement_condition", columnDefinition = "TEXT")
    private String replacementCondition;

    @Column(name = "datasheet_url", columnDefinition = "TEXT")
    private String datasheetUrl;

    @Column(name = "image_url", columnDefinition = "TEXT")
    private String imageUrl;

    @Column(columnDefinition = "TEXT")
    private String note;

    @Column(name = "manufacturing_status", nullable = false, length = 30)
    @Builder.Default
    private String manufacturingStatus = "ACTIVE";

    @Column(name = "category_id", nullable = false)
    private UUID categoryId;

    @Column(name = "footprint_id")
    private UUID footprintId;

    @Column(name = "manufacturer_id")
    private UUID manufacturerId;

    @Column(name = "measurement_unit_id")
    private UUID measurementUnitId;
}
