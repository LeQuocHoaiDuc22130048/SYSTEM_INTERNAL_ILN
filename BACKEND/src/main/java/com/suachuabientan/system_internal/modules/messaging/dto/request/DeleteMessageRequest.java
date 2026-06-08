package com.suachuabientan.system_internal.modules.messaging.dto.request;

import jakarta.validation.constraints.NotBlank;

public record DeleteMessageRequest(
        @NotBlank(message = "Pham vi xoa tin nhan khong duoc de trong")
        String scope
) {
}
