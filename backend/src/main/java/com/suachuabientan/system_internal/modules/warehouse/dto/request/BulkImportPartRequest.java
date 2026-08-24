package com.suachuabientan.system_internal.modules.warehouse.dto.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import java.util.List;

public record BulkImportPartRequest(
        @NotEmpty(message = "Danh sách linh kiện nhập không được để trống")
        @Valid
        List<BulkImportPartItemRequest> items,

        boolean updateIfExists
) {
}
