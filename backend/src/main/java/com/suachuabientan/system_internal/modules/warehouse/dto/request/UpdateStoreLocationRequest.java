package com.suachuabientan.system_internal.modules.warehouse.dto.request;

import jakarta.validation.constraints.Size;

public record UpdateStoreLocationRequest(
        @Size(max = 80, message = "Mã vị trí kho tối đa 80 ký tự")
        String code,

        @Size(max = 200, message = "Tên vị trí kho tối đa 200 ký tự")
        String name,

        String description,

        String qrCode
) {
}
