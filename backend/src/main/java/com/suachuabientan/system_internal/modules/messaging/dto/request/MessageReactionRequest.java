package com.suachuabientan.system_internal.modules.messaging.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record MessageReactionRequest(
        @NotBlank(message = "Emoji khong duoc de trong")
        @Size(max = 16, message = "Emoji khong hop le")
        String emoji
) {
}
