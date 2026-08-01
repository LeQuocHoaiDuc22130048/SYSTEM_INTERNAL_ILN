package com.suachuabientan.system_internal.modules.warehouse.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record PartResponse(
        UUID id,
        String ipn,
        String name,
        String description,
        BigDecimal minAmount,
        BigDecimal maxAmount,
        BigDecimal purchasePrice,
        BigDecimal salePrice,
        String parameters,
        String datasheetUrl,
        String imageUrl,
        String note,
        String manufacturingStatus,
        UUID categoryId,
        String categoryName,
        UUID footprintId,
        UUID manufacturerId,
        UUID measurementUnitId,
        BigDecimal totalQuantity,
        List<PartLotResponse> lots,
        Instant createdAt
) {
}

