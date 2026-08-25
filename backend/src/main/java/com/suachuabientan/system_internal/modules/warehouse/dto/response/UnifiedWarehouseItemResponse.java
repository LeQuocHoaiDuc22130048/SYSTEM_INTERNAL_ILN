package com.suachuabientan.system_internal.modules.warehouse.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record UnifiedWarehouseItemResponse(
        UUID id,
        String itemType,
        String name,
        String code,
        String qrCode,
        String categoryName,
        String location,
        UUID storeLocationId,
        BigDecimal quantity,
        BigDecimal minQuantity,
        String unit,
        String status,
        String model,
        String description,
        String imageUrl,
        String holderName,
        Instant updatedAt,
        List<PartLotInfo> lots
) {
    public record PartLotInfo(
            UUID id,
            UUID storeLocationId,
            String storeLocationCode,
            String storeLocationName,
            BigDecimal amount,
            String condition
    ) {}
}
