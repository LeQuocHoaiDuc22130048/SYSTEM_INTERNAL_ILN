package com.suachuabientan.system_internal.modules.messaging.dto.request;

import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.UUID;

public record UpdateMessageRequest(
        @Size(max = 4000, message = "Noi dung tin nhan toi da 4000 ky tu")
        String content,
        List<UUID> mentionUserIds
) {
}
