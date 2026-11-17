package com.suachuabientan.system_internal.modules.quotation.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import com.suachuabientan.system_internal.modules.quotation.enums.QuotationStatus;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "repair_quotations")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RepairQuotation extends BaseEntity {

    @Column(name = "quote_code", nullable = false, unique = true, length = 30)
    private String quoteCode;

    @Column(name = "customer_id", nullable = false)
    private UUID customerId;

    @Column(name = "customer_name", nullable = false, length = 150)
    private String customerName;

    @Column(name = "customer_phone", length = 30)
    private String customerPhone;

    @Column(length = 250)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String note;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    @Builder.Default
    private QuotationStatus status = QuotationStatus.DRAFT;

    @Column(name = "total_estimated_amount", nullable = false, precision = 15, scale = 2)
    @Builder.Default
    private BigDecimal totalEstimatedAmount = BigDecimal.ZERO;

    @Column(name = "total_approved_amount", nullable = false, precision = 15, scale = 2)
    @Builder.Default
    private BigDecimal totalApprovedAmount = BigDecimal.ZERO;

    @Column(name = "sent_at")
    private Instant sentAt;

    @Column(name = "responded_at")
    private Instant respondedAt;

    @Column(name = "expires_at")
    private Instant expiresAt;

    @OneToMany(mappedBy = "quotation", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @OrderBy("sortOrder ASC")
    @Builder.Default
    private List<RepairQuotationItem> items = new ArrayList<>();
}

