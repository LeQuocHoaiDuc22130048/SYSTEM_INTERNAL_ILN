package com.suachuabientan.system_internal.modules.messaging.dto.request;

import jakarta.validation.constraints.NotBlank;

import java.util.List;
import java.util.UUID;

public record SendMessageRequest(
        String content,
        String mediaUrl,

        @NotBlank(message = "Loai tin nhan khong duoc de trong")
        String messageType,

        List<UUID> mentionUserIds
) {
}
