package com.suachuabientan.system_internal.modules.warehouse.dto.request;

import jakarta.validation.constraints.NotBlank;
import java.math.BigDecimal;
import java.util.UUID;

public record CreatePartRequest(
        @NotBlank(message = "IPN không được để trống")
        String ipn,

        @NotBlank(message = "Tên linh kiện không được để trống")
        String name,

        String description,

        BigDecimal minAmount,

        String categoryName,

        UUID categoryId
) {
}
