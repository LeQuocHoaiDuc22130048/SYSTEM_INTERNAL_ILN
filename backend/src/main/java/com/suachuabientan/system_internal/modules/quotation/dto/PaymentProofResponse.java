package com.suachuabientan.system_internal.modules.quotation.dto;

import com.suachuabientan.system_internal.modules.quotation.enums.PaymentProofStatus;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record PaymentProofResponse(
        UUID id,
        UUID quotationId,
        BigDecimal amount,
        String transferContent,
        String proofFileUrl,
        String proofFileName,
        String note,
        PaymentProofStatus status,
        String statusLabel,
        UUID verifiedBy,
        Instant verifiedAt,
        String rejectionReason,
        Instant createdAt
) {
}

