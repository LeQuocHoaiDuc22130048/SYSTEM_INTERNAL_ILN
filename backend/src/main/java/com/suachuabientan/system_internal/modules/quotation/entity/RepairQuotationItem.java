package com.suachuabientan.system_internal.modules.quotation.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import com.suachuabientan.system_internal.modules.quotation.enums.QuotationItemDecision;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "repair_quotation_items")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RepairQuotationItem extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "quotation_id", nullable = false)
    private RepairQuotation quotation;

    @Column(name = "repair_order_id", nullable = false)
    private UUID repairOrderId;

    @Column(name = "order_code", nullable = false, length = 30)
    private String orderCode;

    @Column(name = "device_name", nullable = false, length = 200)
    private String deviceName;

    @Column(name = "device_type", length = 100)
    private String deviceType;

    @Column(name = "serial_number", length = 100)
    private String serialNumber;

    @Column(name = "diagnosed_errors_json", columnDefinition = "TEXT")
    private String diagnosedErrorsJson;

    @Column(name = "base_cost", nullable = false, precision = 15, scale = 2)
    @Builder.Default
    private BigDecimal baseCost = BigDecimal.ZERO;

    @Column(name = "warranty_options_json", columnDefinition = "TEXT")
    private String warrantyOptionsJson;

    @Column(name = "selected_warranty_code", length = 50)
    private String selectedWarrantyCode;

    @Column(name = "selected_warranty_label", length = 150)
    private String selectedWarrantyLabel;

    @Column(name = "warranty_fee", nullable = false, precision = 15, scale = 2)
    @Builder.Default
    private BigDecimal warrantyFee = BigDecimal.ZERO;

    @Column(name = "final_amount", nullable = false, precision = 15, scale = 2)
    @Builder.Default
    private BigDecimal finalAmount = BigDecimal.ZERO;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private QuotationItemDecision decision = QuotationItemDecision.PENDING;

    @Column(name = "reject_reason", columnDefinition = "TEXT")
    private String rejectReason;

    @Column(name = "decided_at")
    private Instant decidedAt;

    @Column(name = "sort_order", nullable = false)
    @Builder.Default
    private Integer sortOrder = 0;

    @OneToMany(mappedBy = "quotationItem", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @OrderBy("sortOrder ASC")
    @Builder.Default
    private List<RepairQuotationLineItem> lineItems = new ArrayList<>();
}

