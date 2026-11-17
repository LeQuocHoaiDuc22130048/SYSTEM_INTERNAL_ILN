package com.suachuabientan.system_internal.modules.quotation.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record CreateQuotationRequest(
        UUID customerId,
        String title,
        String note,
        Instant expiresAt,
        Boolean sendImmediately,
        @NotEmpty(message = "Báo giá phải có ít nhất 1 thiết bị")
        @Valid
        List<CreateQuotationItemRequest> items
) {
}

