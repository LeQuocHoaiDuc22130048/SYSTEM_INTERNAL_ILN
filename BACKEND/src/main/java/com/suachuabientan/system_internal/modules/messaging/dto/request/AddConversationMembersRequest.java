package com.suachuabientan.system_internal.modules.messaging.dto.request;

import jakarta.validation.constraints.NotEmpty;

import java.util.List;
import java.util.UUID;

public record AddConversationMembersRequest(
        @NotEmpty(message = "Danh sách thành viên không được để trống")
        List<UUID> memberIds
) {
}
