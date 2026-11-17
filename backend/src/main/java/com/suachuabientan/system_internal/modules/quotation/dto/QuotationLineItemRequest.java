package com.suachuabientan.system_internal.modules.quotation.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record QuotationLineItemRequest(
        @NotBlank(message = "Tên hạng mục không được để trống")
        String description,
        @NotNull(message = "Số lượng không được để trống")
        @Min(value = 1, message = "Số lượng tối thiểu là 1")
        Integer quantity,
        @NotNull(message = "Đơn giá không được để trống")
        @DecimalMin(value = "0", message = "Đơn giá không được âm")
        BigDecimal unitPrice
) {
}

