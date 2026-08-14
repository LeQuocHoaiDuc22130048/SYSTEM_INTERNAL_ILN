package com.suachuabientan.system_internal.modules.warehouse.dto.response;

import java.math.BigDecimal;
import java.util.UUID;

public record PartLotResponse(
        UUID id,
        UUID storeLocationId,
        String storeLocationCode,
        String storeLocationName,
        BigDecimal amount,
        String lotCode
) {
}
