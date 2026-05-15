package com.suachuabientan.system_internal.modules.repair.dto.request;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.util.List;
import java.util.UUID;

public record ReorderRequest(@NotEmpty(message = "Danh sách không được để trống")
                             List<PriorityItem> items
) {
    public record PriorityItem(
            @NotNull UUID orderId,
            @NotNull Integer priority
    ) {
    }
}
