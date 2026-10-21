package com.suachuabientan.system_internal.modules.customer.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record UpdateCustomerAccountProfileRequest(
        @NotBlank(message = "Tên người liên hệ không được để trống")
        @Size(max = 100, message = "Tên người liên hệ tối đa 100 ký tự")
        String contactName,

        @Pattern(regexp = "^(0|\\+84)[0-9]{9,10}$|^$", message = "Số điện thoại không hợp lệ (9-10 chữ số)")
        String phone,

        @Email(message = "Email không hợp lệ")
        @Size(max = 254, message = "Email tối đa 254 ký tự")
        String email
) {}
