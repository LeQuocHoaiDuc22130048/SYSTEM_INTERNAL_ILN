package com.suachuabientan.system_internal.modules.quotation.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public record RespondQuotationRequest(
        @NotEmpty(message = "Danh sách quyết định theo từng máy không được để trống")
        @Valid
        List<QuotationItemDecisionRequest> items
) {
}

