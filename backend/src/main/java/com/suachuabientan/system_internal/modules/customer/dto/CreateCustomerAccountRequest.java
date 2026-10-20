package com.suachuabientan.system_internal.modules.customer.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateCustomerAccountRequest(
        @NotBlank(message = "Tên đăng nhập không được để trống")
        @Size(min = 3, max = 50, message = "Tên đăng nhập từ 3 đến 50 ký tự")
        String username,

        @NotBlank(message = "Mật khẩu không được để trống")
        @Size(min = 6, message = "Mật khẩu tối thiểu 6 ký tự")
        String password,

        @NotBlank(message = "Tên người liên hệ không được để trống")
        @Size(max = 100, message = "Tên người liên hệ tối đa 100 ký tự")
        String contactName,

        String phone,
        String email,
        Boolean mustChangePassword
) {
}
