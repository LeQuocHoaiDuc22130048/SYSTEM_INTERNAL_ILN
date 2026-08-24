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
        String serialNumber,
        String model,
        String boardType,
        String firmware,
        String removedParts,
        java.time.LocalDate receivedDate,
        String note,
        UUID partId,
        String partIpn,
        UUID currentLocationId,
        String currentLocationCode,
        Instant createdAt,
        Integer quantity,
        Integer minQuantity,

        ActiveCheckoutInfo activeCheckoutInfo
) {
    public record ActiveCheckoutInfo(
            UUID checkoutId,
            UUID takenBy,
            String takenByName,
            String takenByEmployeeCode,
            Instant takenAt,
            UUID repairOrderId,
            String orderCode,
            Integer quantity,
            String repairBrand
    ) {
    }
}

