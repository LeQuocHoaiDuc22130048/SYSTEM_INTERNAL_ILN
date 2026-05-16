package com.suachuabientan.system_internal.modules.messaging.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.NotBlank;

public record SendMessageRequest(
        String content,
        String mediaUrl,

        @NotBlank(message = "Loai tin nhan khong duoc de trong")
        String messageType
) {
}
