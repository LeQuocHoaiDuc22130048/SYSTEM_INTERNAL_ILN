package com.suachuabientan.system_internal.modules.customer.dto;

import jakarta.validation.constraints.NotBlank;

public record CustomerOrderConfirmRequest(
        @NotBlank(message = "Hành động xác nhận không được để trống")
        String action,
        Integer warrantyMonths,
        String rejectionReason
) {
}

