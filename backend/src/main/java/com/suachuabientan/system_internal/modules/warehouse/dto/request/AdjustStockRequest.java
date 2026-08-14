package com.suachuabientan.system_internal.modules.warehouse.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;

public record AdjustStockRequest(
        @NotBlank(message = "Mã vị trí kho không được để trống")
        String storeLocationCode,

        @NotNull(message = "Số lượng không được để trống")
        BigDecimal amount,

        String note
) {
}
