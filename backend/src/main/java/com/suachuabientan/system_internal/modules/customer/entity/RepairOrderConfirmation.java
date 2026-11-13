package com.suachuabientan.system_internal.modules.customer.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "repair_order_confirmations")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RepairOrderConfirmation extends BaseEntity {

    @Column(name = "order_id", nullable = false, unique = true)
    private UUID orderId;

    @Column(name = "confirmation_status", nullable = false, length = 32)
    @Builder.Default
    private String confirmationStatus = "PENDING_CUSTOMER";

    @Column(name = "warranty_months", nullable = false)
    @Builder.Default
    private Integer warrantyMonths = 6;

    @Column(name = "warranty_extra_fee", nullable = false)
    @Builder.Default
    private Long warrantyExtraFee = 0L;

    @Column(name = "base_amount", nullable = false)
    @Builder.Default
    private Long baseAmount = 0L;

    @Column(name = "total_amount", nullable = false)
    @Builder.Default
    private Long totalAmount = 0L;

    @Column(name = "diagnosis_tags_json", columnDefinition = "TEXT")
    private String diagnosisTagsJson;

    @Column(name = "quote_items_json", columnDefinition = "TEXT")
    private String quoteItemsJson;

    @Column(name = "rejection_reason", columnDefinition = "TEXT")
    private String rejectionReason;

    @Column(name = "payment_proof_url", length = 500)
    private String paymentProofUrl;

    @Column(name = "payment_proof_file_name", length = 255)
    private String paymentProofFileName;

    @Column(name = "transfer_reference", length = 150)
    private String transferReference;

    @Column(name = "confirmed_by_user_id")
    private UUID confirmedByUserId;

    @Column(name = "approved_at")
    private Instant approvedAt;

    @Column(name = "rejected_at")
    private Instant rejectedAt;

    @Column(name = "payment_submitted_at")
    private Instant paymentSubmittedAt;
}

