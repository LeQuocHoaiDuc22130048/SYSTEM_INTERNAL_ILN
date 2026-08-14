package com.suachuabientan.system_internal.modules.warehouse.dto.response;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record LocationScanResponse(
        UUID locationId,
        String code,
        String name,
        String description,
        String qrCode,
        Boolean isFull,
        List<LocationPartItem> parts,
        int totalPartTypes,
        BigDecimal totalQuantity
) {
    public record LocationPartItem(
            UUID partId,
            UUID partLotId,
            String ipn,
            String name,
            String description,
            BigDecimal amount,
            String unit,
            String categoryName,
            String imageUrl,
            String condition
    ) {}
}
