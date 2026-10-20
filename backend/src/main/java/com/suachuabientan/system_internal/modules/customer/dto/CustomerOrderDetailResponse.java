package com.suachuabientan.system_internal.modules.customer.dto;

import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record CustomerOrderDetailResponse(
        UUID id,
        String orderCode,
        RepairStatus status,
        String statusLabel,
        Instant receivedAt,
        Instant estimatedDone,
        Instant completedAt,
        Instant deliveredAt,
        String customerName,
        String description,
        List<CustomerDeviceResponse> devices,
        List<CustomerUpdateResponse> updates,
        List<CustomerMediaResponse> media
) {
}
