package com.suachuabientan.system_internal.modules.warehouse.dto.request;

import jakarta.validation.constraints.NotBlank;
import java.math.BigDecimal;

public record BulkImportPartItemRequest(
        @NotBlank(message = "Mã IPN không được để trống")
        String ipn,

        @NotBlank(message = "Tên linh kiện không được để trống")
        String name,

        String categoryName,

        String description,

        String storeLocationCode,

        BigDecimal quantity,

        BigDecimal minAmount,

        BigDecimal maxAmount,

        BigDecimal purchasePrice,

        BigDecimal salePrice,

        String parameters,

        String footprint,

        String note,

        String condition
) {
}
