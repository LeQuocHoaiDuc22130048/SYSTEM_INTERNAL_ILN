package com.suachuabientan.system_internal.modules.quotation.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import com.suachuabientan.system_internal.modules.quotation.enums.PaymentProofStatus;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "repair_payment_proofs")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RepairPaymentProof extends BaseEntity {

    @Column(name = "quotation_id", nullable = false)
    private UUID quotationId;

    @Column(nullable = false, precision = 15, scale = 2)
    private BigDecimal amount;

    @Column(name = "transfer_content", nullable = false, length = 200)
    private String transferContent;

    @Column(name = "proof_file_url", nullable = false, length = 500)
    private String proofFileUrl;

    @Column(name = "proof_file_name", length = 255)
    private String proofFileName;

    @Column(columnDefinition = "TEXT")
    private String note;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    @Builder.Default
    private PaymentProofStatus status = PaymentProofStatus.PENDING_VERIFY;

    @Column(name = "verified_by")
    private UUID verifiedBy;

    @Column(name = "verified_at")
    private Instant verifiedAt;

    @Column(name = "rejection_reason", columnDefinition = "TEXT")
    private String rejectionReason;
}

