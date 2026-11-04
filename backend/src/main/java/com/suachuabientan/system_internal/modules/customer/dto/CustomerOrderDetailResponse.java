package com.suachuabientan.system_internal.modules.customer.dto;

import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record CustomerOrderDetailResponse(
        UUID id,
        String orderCode,
        String orderTitle,
        String deviceName,
        String deviceType,
        String serialNumber,
        RepairStatus status,
        String statusLabel,
        String friendlyStatus,
        Instant receivedAt,
        Instant receivedDate,
        Instant estimatedDone,
        Instant expectedDeliveryDate,
        Instant completedAt,
        Instant deliveredAt,
        String customerName,
        String description,
        String assignedTechnicianName,
        String assignedTechnicianCode,
        String receivedByName,
        List<CustomerDeviceResponse> devices,
        List<CustomerUpdateResponse> updates,
        List<CustomerMediaResponse> media
) {
    public CustomerOrderDetailResponse(
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
        this(
                id,
                orderCode,
                devices != null && !devices.isEmpty()
                        ? CustomerOrderResponse.buildOrderTitle(devices.get(0).deviceName(), devices.get(0).deviceType(), description)
                        : CustomerOrderResponse.buildOrderTitle(null, null, description),
                devices != null && !devices.isEmpty() ? devices.get(0).deviceName() : null,
                devices != null && !devices.isEmpty() ? devices.get(0).deviceType() : null,
                devices != null && !devices.isEmpty() ? devices.get(0).serialNumber() : null,
                status,
                statusLabel,
                statusLabel,
                receivedAt,
                receivedAt,
                estimatedDone,
                estimatedDone,
                completedAt,
                deliveredAt,
                customerName,
                description,
                null,
                null,
                null,
                devices,
                updates,
                media
        );
    }
}
