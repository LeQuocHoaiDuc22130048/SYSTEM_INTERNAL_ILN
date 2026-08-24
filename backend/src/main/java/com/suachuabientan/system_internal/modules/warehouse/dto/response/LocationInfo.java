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
        BigDecimal totalQuantity
) {
    public LocationInfo(UUID id, String code, String name) {
        this(id, code, name, null, code, 0, BigDecimal.ZERO);
    }
}
