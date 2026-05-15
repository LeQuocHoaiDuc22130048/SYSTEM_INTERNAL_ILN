package com.suachuabientan.system_internal.modules.repair.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record CreateRepairOrderRequest(

        @NotBlank(message = "Tên thiết bị không được để trống")
        @Size(max = 200)
        String deviceName,

        @Size(max = 100)
        String deviceType,

        @NotBlank(message = "Tên khách hàng không được để trống")
        @Size(max = 100)
        String customerName,

        @NotBlank(message = "Số điện thoại không được để trống")
        @Pattern(regexp = "^[0-9]{10,11}$", message = "Số điện thoại phải có 10–11 chữ số")
        String customerPhone,

        @NotBlank(message = "Mô tả tình trạng không được để trống")
        String description
) {
}
