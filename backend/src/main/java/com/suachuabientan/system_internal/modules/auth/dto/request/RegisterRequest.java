package com.suachuabientan.system_internal.modules.auth.dto.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record RegisterRequest (
        @NotBlank(message = "Tên đăng nhập không được để trống")
        @Size(min = 4, max = 50, message = "Tên đăng nhập từ 4–50 ký tự")
        @Pattern(regexp = "^[a-zA-Z0-9._]+$", message = "Tên đăng nhập chỉ chứa chữ, số, dấu chấm và gạch dưới")
        String username,

        /**
         * Tối thiểu 8 ký tự, có chữ hoa, chữ thường, số — SEC-04.
         */
        @NotBlank(message = "Mật khẩu không được để trống")
        @Pattern(
                regexp = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{8,}$",
                message = "Mật khẩu tối thiểu 8 ký tự, bao gồm chữ hoa, chữ thường và số"
        )
        String password,

        @NotBlank(message = "Họ tên không được để trống")
        @Size(max = 100, message = "Họ tên tối đa 100 ký tự")
        String fullName,

        @Size(max = 100, message = "Tên bộ phận tối đa 100 ký tự")
        String department,

        @Pattern(regexp = "^[0-9]{10,11}$", message = "Số điện thoại phải có 10–11 chữ số")
        String phone
) {}
