package com.suachuabientan.system_internal.modules.repair.dto.request;

import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import jakarta.validation.constraints.NotNull;

public record UpdateStatusRequest(
        @NotNull(message = "Trạng thái không được để trống")
        RepairStatus status,
        String note
) {
}
