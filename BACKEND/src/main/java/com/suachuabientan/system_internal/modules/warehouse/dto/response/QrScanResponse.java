package com.suachuabientan.system_internal.modules.warehouse.dto.response;

import java.time.Instant;
import java.util.UUID;

public record QrScanResponse(
        UUID boardItemId,
        String qrCode,
        String name,
        String category,
        String location,
        String serialNumber,
        UUID partId,
        String partIpn,
        UUID currentLocationId,
        String currentLocationCode,
        String status,
        Integer quantity,

        HolderInfo holder
) {
    public record HolderInfo(
            UUID userId,
            String fullName,
            String employeeCode,
            String avatarUrl,
            Instant takenAt,
            String orderCode,
            Integer quantityTaken,
            String repairBrand
    ) {
    }
}
