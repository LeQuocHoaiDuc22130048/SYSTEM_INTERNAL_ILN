package com.suachuabientan.system_internal.modules.warehouse.dto.request;

import java.math.BigDecimal;
import java.util.UUID;

public record UpdatePartRequest(
        String ipn,
        String name,
        String description,
        BigDecimal minAmount,
        String categoryName,
        UUID categoryId
) {
}
