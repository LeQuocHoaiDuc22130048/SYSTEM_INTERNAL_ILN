package com.suachuabientan.system_internal.modules.auth.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record RequestPasswordResetOtpRequest(
        @NotBlank(message = "Ten dang nhap khong duoc de trong")
        @Size(min = 4, max = 50, message = "Ten dang nhap tu 4-50 ky tu")
        @Pattern(regexp = "^[a-zA-Z0-9._]+$", message = "Ten dang nhap khong hop le")
        String username,

        @NotBlank(message = "So dien thoai khong duoc de trong")
        @Pattern(regexp = "^[0-9]{10,11}$", message = "So dien thoai phai co 10-11 chu so")
        String phone
) {
}
