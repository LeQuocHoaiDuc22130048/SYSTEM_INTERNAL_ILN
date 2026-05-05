package com.suachuabientan.system_internal.modules.auth.dto.request;

import com.suachuabientan.system_internal.common.enums.ApprovalAction;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record ApproveUserRequest(
        @NotNull(message = "Hành động không được để trống")
        ApprovalAction action,

        @Size(max = 500, message = "Ghi chú tối đa 500 ký tự")
        String note
) {
}
