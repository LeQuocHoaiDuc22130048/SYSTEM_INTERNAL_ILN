package com.suachuabientan.system_internal.modules.notification.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UpdateDeviceTokenRequest(
        @NotBlank(message = "Device token khong duoc de trong")
        @Size(max = 500, message = "Device token toi da 500 ky tu")
        String deviceToken
) {
}
