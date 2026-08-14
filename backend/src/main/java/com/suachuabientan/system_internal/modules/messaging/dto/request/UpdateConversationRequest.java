package com.suachuabientan.system_internal.modules.messaging.dto.request;

import jakarta.validation.constraints.Size;

public record UpdateConversationRequest(
        @Size(max = 100, message = "Ten nhom toi da 100 ky tu")
        String name,

        @Size(max = 500, message = "Avatar URL toi da 500 ky tu")
        String avatarUrl
) {
}
