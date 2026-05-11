package com.suachuabientan.system_internal.modules.warehouse.dto.response;

import java.time.Instant;
import java.util.UUID;

public record CheckoutResponse(
        UUID checkoutId,
        UUID boardItemId,
        String boardName,
        String qrCode,
        UUID takenBy,
        String takenByName,
        Instant takenAt,
        Instant returnAt,
        UUID repairOrderId,
        String note
) {
}
