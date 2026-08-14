package com.suachuabientan.system_internal.modules.warehouse.dto.request;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.util.UUID;

public record PartCheckoutRequest(
        @NotNull(message = "ID vị trí kho không được để trống")
        UUID storeLocationId,

        UUID partLotId,

        @NotNull(message = "Số lượng lấy không được để trống")
        @DecimalMin(value = "0.0001", message = "Số lượng phải lớn hơn 0")
        BigDecimal quantity,

        String purpose,
        UUID repairOrderId,
        String notes
) {}
