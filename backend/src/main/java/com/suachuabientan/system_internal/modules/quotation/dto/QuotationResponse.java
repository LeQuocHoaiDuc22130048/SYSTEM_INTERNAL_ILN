package com.suachuabientan.system_internal.modules.quotation.dto;

import com.suachuabientan.system_internal.modules.quotation.enums.QuotationStatus;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record QuotationResponse(
        UUID id,
        String quoteCode,
        UUID customerId,
        String customerName,
        String customerPhone,
        String title,
        String note,
        QuotationStatus status,
        String statusLabel,
        BigDecimal totalEstimatedAmount,
        BigDecimal totalApprovedAmount,
        Instant sentAt,
        Instant respondedAt,
        Instant expiresAt,
        Instant createdAt,
        int itemCount,
        int approvedItemCount,
        int rejectedItemCount,
        int pendingItemCount,
        QuotationBankInfoResponse bankInfo,
        List<QuotationItemResponse> items,
        List<PaymentProofResponse> paymentProofs
) {
}

