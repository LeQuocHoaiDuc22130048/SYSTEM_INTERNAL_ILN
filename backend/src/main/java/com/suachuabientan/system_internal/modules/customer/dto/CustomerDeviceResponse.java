package com.suachuabientan.system_internal.modules.customer.dto;

import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import java.time.LocalDate;
import java.util.UUID;

public record CustomerDeviceResponse(
        UUID id,
        String deviceName,
        String modelName,
        String deviceType,
        String model,
        String serialNumber,
        String description,
        String issueDescription,
        String symptom,
        RepairStatus status,
        String statusLabel,
        String friendlyStatus,
        Boolean underWarranty,
        LocalDate warrantyExpiry,
        String assignedTechnicianName
) {
    public CustomerDeviceResponse(
            UUID id,
            String deviceName,
            String deviceType,
            String serialNumber,
            String description,
            RepairStatus status,
            String statusLabel,
            Boolean underWarranty
    ) {
        this(
                id,
                deviceName,
                deviceName,
                deviceType,
                deviceType,
                serialNumber,
                description,
                description,
                description,
                status,
                statusLabel,
                statusLabel,
                underWarranty,
                null,
                null
        );
    }
}
