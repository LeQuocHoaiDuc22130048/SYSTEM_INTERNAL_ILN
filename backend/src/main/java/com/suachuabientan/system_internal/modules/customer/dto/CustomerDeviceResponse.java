package com.suachuabientan.system_internal.modules.customer.dto;

import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import java.util.UUID;

public record CustomerDeviceResponse(
        UUID id,
        String deviceName,
        String deviceType,
        String serialNumber,
        String description,
        RepairStatus status,
        String statusLabel,
        Boolean underWarranty
) {
}
