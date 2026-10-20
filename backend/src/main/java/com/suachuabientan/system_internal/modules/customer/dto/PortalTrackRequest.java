package com.suachuabientan.system_internal.modules.customer.dto;

import jakarta.validation.constraints.NotBlank;

public record PortalTrackRequest(
        @NotBlank(message = "Mã đơn hàng không được để trống")
        String orderCode,

        @NotBlank(message = "Số điện thoại không được để trống")
        String phone
) {
}
