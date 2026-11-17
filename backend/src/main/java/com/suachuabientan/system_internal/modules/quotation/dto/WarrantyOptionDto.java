package com.suachuabientan.system_internal.modules.quotation.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record WarrantyOptionDto(
        @NotBlank(message = "Mã gói bảo hành không được để trống")
        String code,
        @NotBlank(message = "Tên gói bảo hành không được để trống")
        String label,
        String description,
        @NotNull @Min(1)
        Integer months,
        @NotNull @Min(0)
        BigDecimal fee
) {
}

