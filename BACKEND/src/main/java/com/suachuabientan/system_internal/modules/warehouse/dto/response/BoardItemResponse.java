package com.suachuabientan.system_internal.modules.warehouse.dto.response;

import java.time.Instant;
import java.util.UUID;

public record BoardItemResponse(
        UUID id,
        String qrCode,
        String name,
        String category,
        String description,
        String status,
        String location,
        Instant createdAt,

        ActiveCheckoutInfo activeCheckoutInfo
) {
    public record ActiveCheckoutInfo(
            UUID checkoutId,
            UUID takenBy,
            String takenByName,
            String takenByEmployeeCode,
            Instant takenAt,
            UUID repairOrderId,
            String orderCode
    ) {
    }
}
