package com.suachuabientan.system_internal.modules.repair.dto.request;

import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record AssignRequest(
        @NotNull(message = "Kỹ thuật viên không được để trống")
        UUID technicianId,
        String note
) {
}
