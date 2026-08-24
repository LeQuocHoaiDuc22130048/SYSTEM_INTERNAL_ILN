package com.suachuabientan.system_internal.modules.warehouse.dto.response;

import java.util.List;

public record BulkImportPartResponse(
        int totalRows,
        int successCount,
        int updatedCount,
        int failedCount,
        List<BulkImportErrorItem> errors,
        List<PartResponse> items
) {
    public record BulkImportErrorItem(
            int rowNumber,
            String ipn,
            String errorMessage
    ) {
    }
}
