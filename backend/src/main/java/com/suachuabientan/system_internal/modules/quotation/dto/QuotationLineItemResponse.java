package com.suachuabientan.system_internal.modules.quotation.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record QuotationLineItemResponse(
        UUID id,
        String description,
        Integer quantity,
        BigDecimal unitPrice,
        BigDecimal amount,
        Integer sortOrder
) {
}

