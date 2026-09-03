package com.suachuabientan.system_internal.modules.warehouse.dto.response;

import java.math.BigDecimal;
import java.util.UUID;

public record LocationInfo(
        UUID id,
        String code,
        String name,
        String description,
        String qrCode,
        Integer totalPartTypes,
        BigDecimal totalQuantity,
        Integer partTypesCount,
        BigDecimal partQuantity,
        Integer boardTypesCount,
        BigDecimal boardQuantity
) {
    public LocationInfo(UUID id, String code, String name) {
        this(id, code, name, null, code, 0, BigDecimal.ZERO, 0, BigDecimal.ZERO, 0, BigDecimal.ZERO);
    }

    public LocationInfo(
            UUID id,
            String code,
            String name,
            String description,
            String qrCode,
            Integer totalPartTypes,
            BigDecimal totalQuantity
    ) {
        this(id, code, name, description, qrCode, totalPartTypes, totalQuantity, totalPartTypes, totalQuantity, 0, BigDecimal.ZERO);
    }
}
