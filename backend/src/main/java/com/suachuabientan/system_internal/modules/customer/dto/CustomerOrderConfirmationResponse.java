package com.suachuabientan.system_internal.modules.customer.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record CustomerOrderConfirmationResponse(
        UUID orderId,
        String confirmationStatus,
        int warrantyMonths,
        long warrantyExtraFee,
        long baseAmount,
        long totalAmount,
        List<String> diagnosisTags,
        List<OrderQuoteLineItemDto> quoteItems,
        String bankName,
        String bankCode,
        String accountNumber,
        String accountHolder,
        String transferContent,
        String paymentProofUrl,
        String paymentProofFileName,
        String rejectionReason,
        Instant approvedAt,
        Instant rejectedAt,
        Instant paymentSubmittedAt
) {
}

