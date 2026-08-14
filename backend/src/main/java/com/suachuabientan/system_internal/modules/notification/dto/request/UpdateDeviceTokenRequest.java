package com.suachuabientan.system_internal.modules.notification.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UpdateDeviceTokenRequest(
        @NotBlank(message = "Device token không được để trống")
        @Size(max = 500, message = "Device token tối đa 500 ký tự")
        String deviceToken
) {
}
