package com.suachuabientan.system_internal.modules.messaging.dto.request;

import jakarta.validation.constraints.NotBlank;

public record UpdateMemberRoleRequest(
        @NotBlank(message = "Vai tro thanh vien khong duoc de trong")
        String role,
        Boolean canChat
) {
}
