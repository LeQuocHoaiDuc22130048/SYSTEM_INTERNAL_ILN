package com.suachuabientan.system_internal.modules.repair.dto.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

import java.util.List;

public record CreateRepairOrderRequest(

        @NotBlank(message = "Tên khách hàng không được để trống")
        @Size(max = 100)
        String customerName,

        @Size(max = 20)
        String customerPhone,

        /** Danh sách thiết bị (ít nhất 1) */
        @NotEmpty(message = "Phải có ít nhất một thiết bị")
        @Valid
        List<CreateRepairDeviceRequest> devices
) {
}
