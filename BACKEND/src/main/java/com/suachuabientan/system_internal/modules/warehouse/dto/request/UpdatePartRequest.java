package com.suachuabientan.system_internal.modules.warehouse.dto.request;

import java.math.BigDecimal;
import java.util.UUID;

public record UpdatePartRequest(
        String ipn,
        String name,
        String description,
        BigDecimal minAmount,
        BigDecimal maxAmount,
        BigDecimal purchasePrice,
        BigDecimal salePrice,
        String manufacturingStatus,
        String parameters,
        String datasheetUrl,
        String imageUrl,
        String note,
        String categoryName,
        UUID categoryId,
        UUID footprintId,
        UUID manufacturerId,
        UUID measurementUnitId
) {
}

