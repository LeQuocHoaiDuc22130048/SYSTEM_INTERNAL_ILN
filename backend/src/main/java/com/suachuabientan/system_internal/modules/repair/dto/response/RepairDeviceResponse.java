package com.suachuabientan.system_internal.modules.repair.dto.response;

import java.time.Instant;
import java.util.UUID;

public record RepairDeviceResponse(
        UUID id,
        String deviceName,
        String deviceType,
        String serialNumber,
        Boolean underWarranty,
        java.time.LocalDate warrantyExpiry,
        String description,
        String status,
        RepairOrderResponse.UserSummary assignedTo,
        Instant createdAt
) {
}
