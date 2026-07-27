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
        String manufacturingStatus,
        UUID categoryId,
        String categoryName,
        BigDecimal totalQuantity,
        List<PartLotResponse> lots,
        Instant createdAt
) {
}
