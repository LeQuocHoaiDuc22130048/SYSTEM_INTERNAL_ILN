package com.suachuabientan.system_internal.modules.warehouse.dto.request;

import com.suachuabientan.system_internal.modules.warehouse.enums.PartCondition;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;

public record PartReturnRequest(
        @NotNull(message = "Số lượng trả không được để trống")
        @DecimalMin(value = "0.0001", message = "Số lượng trả phải lớn hơn 0")
        BigDecimal returnedQuantity,

        PartCondition conditionStatus,
        String notes
) {}
