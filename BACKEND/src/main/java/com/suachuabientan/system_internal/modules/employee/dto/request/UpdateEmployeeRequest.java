package com.suachuabientan.system_internal.modules.employee.dto.request;

import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record UpdateEmployeeRequest(
        @Size(max = 100, message = "Họ tên tối đa 100 ký tự")
        String fullName,

        @Size(max = 100, message = "Phòng ban tối đa 100 ký tự")
        String department,

        @Pattern(regexp = "^[0-9]{10,11}$", message = "Số điện thoại phải có 10–11 chữ số")
        String phone,

        String address,

        String avatarUrl
) {
}
