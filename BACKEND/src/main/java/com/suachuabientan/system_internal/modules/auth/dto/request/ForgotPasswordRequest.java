package com.suachuabientan.system_internal.modules.auth.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record ForgotPasswordRequest(
        @NotBlank(message = "Ten dang nhap khong duoc de trong")
        @Size(min = 4, max = 50, message = "Ten dang nhap tu 4-50 ky tu")
        @Pattern(regexp = "^[a-zA-Z0-9._]+$", message = "Ten dang nhap chi chua chu, so, dau cham va gach duoi")
        String username,

        @NotBlank(message = "So dien thoai khong duoc de trong")
        @Pattern(regexp = "^[0-9]{10,11}$", message = "So dien thoai phai co 10-11 chu so")
        String phone,

        @NotBlank(message = "Ma OTP khong duoc de trong")
        @Pattern(regexp = "^[0-9]{6}$", message = "Ma OTP phai co 6 chu so")
        String otp,

        @NotBlank(message = "Mat khau moi khong duoc de trong")
        @Pattern(
                regexp = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{8,}$",
                message = "Mat khau moi toi thieu 8 ky tu, bao gom chu hoa, chu thuong va so"
        )
        String newPassword,

        @NotBlank(message = "Xac nhan mat khau khong duoc de trong")
        String confirmPassword
) {
}
