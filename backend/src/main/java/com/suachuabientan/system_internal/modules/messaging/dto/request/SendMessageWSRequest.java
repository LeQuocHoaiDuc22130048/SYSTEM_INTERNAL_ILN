package com.suachuabientan.system_internal.modules.messaging.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record SendMessageWSRequest(
        @NotNull(message = "conversationId không được để trống")
        UUID conversationId,
        String content,
        String mediaUrl,
        @NotBlank(message = "Loại tin nhắn không được để trống")
        String messageType,
        UUID parentMessageId
) {
}
