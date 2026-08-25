package com.suachuabientan.system_internal.modules.warehouse.dto.response;

import java.math.BigDecimal;

public record UnifiedWarehouseSummaryResponse(
        long totalItems,
        BigDecimal totalQuantity,
        long boardCount,
        long partCount,
        long lowStockCount,
        long outOfStockCount
) {}
