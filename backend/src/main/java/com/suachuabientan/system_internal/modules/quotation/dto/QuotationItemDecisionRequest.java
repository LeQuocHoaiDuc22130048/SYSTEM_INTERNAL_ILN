package com.suachuabientan.system_internal.modules.quotation.dto;

import com.suachuabientan.system_internal.modules.quotation.enums.QuotationItemDecision;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record QuotationItemDecisionRequest(
        @NotNull(message = "quotationItemId không được để trống")
        UUID quotationItemId,
        @NotNull(message = "Quyết định duyệt không được để trống")
        QuotationItemDecision decision,
        String selectedWarrantyCode,
        String rejectReason
) {
}

