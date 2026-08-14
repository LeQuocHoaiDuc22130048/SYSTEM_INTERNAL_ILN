package com.suachuabientan.system_internal.modules.auth.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record ChangePasswordRequest(
        @NotBlank(message = "Mat khau hien tai khong duoc de trong")
        String currentPassword,

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
