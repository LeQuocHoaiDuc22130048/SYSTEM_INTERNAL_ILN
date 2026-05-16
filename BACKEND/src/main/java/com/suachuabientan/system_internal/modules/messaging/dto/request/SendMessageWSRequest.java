package com.suachuabientan.system_internal.modules.messaging.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record SendMessageWSRequest(
        @NotNull(message = "conversationId khong duoc de trong")
        UUID conversationId,
        String content,
        String mediaUrl,
        @NotBlank(message = "Loai tin nhan khong duoc de trong")
        String messageType
) {
}
