package com.suachuabientan.system_internal.modules.quotation.dto;

import com.suachuabientan.system_internal.modules.quotation.enums.QuotationItemDecision;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record QuotationItemResponse(
        UUID id,
        UUID repairOrderId,
        String orderCode,
        String deviceName,
        String deviceType,
        String serialNumber,
        List<DiagnosedErrorDto> diagnosedErrors,
        List<QuotationLineItemResponse> lineItems,
        BigDecimal baseCost,
        List<WarrantyOptionDto> warrantyOptions,
        String selectedWarrantyCode,
        String selectedWarrantyLabel,
        BigDecimal warrantyFee,
        BigDecimal finalAmount,
        QuotationItemDecision decision,
        String decisionLabel,
        String rejectReason,
        Instant decidedAt
) {
}

