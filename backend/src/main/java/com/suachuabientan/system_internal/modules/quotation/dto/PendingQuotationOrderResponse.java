package com.suachuabientan.system_internal.modules.quotation.dto;

import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;

import java.time.Instant;
import java.util.UUID;

public record PendingQuotationOrderResponse(
        UUID id,
        String orderCode,
        String deviceName,
        String deviceType,
        String serialNumber,
        RepairStatus status,
        String statusLabel,
        Instant receivedAt,
        String description
) {
}

