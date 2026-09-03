package com.suachuabientan.system_internal.modules.auth.dto.request;

import jakarta.validation.constraints.NotBlank;

public record DeleteAccountRequest(
        @NotBlank(message = "Mật khẩu xác nhận không được để trống")
        String password,

        String reason
) {
}
