package com.suachuabientan.system_internal.modules.repair.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateRepairDeviceRequest(

        @NotBlank(message = "Tên thiết bị không được để trống")
        @Size(max = 200)
        String deviceName,

        @Size(max = 100)
        String deviceType,

        @Size(max = 100)
        String serialNumber,

        Boolean underWarranty,

        java.time.LocalDate warrantyExpiry,

        String description,

        String assignedToId
) {
}
