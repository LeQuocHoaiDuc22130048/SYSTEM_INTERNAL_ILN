package com.suachuabientan.system_internal.modules.warehouse.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateStoreLocationRequest(
        @NotBlank(message = "Mã vị trí kho không được để trống")
        @Size(max = 80, message = "Mã vị trí kho tối đa 80 ký tự")
        String code,

        @NotBlank(message = "Tên vị trí kho không được để trống")
        @Size(max = 200, message = "Tên vị trí kho tối đa 200 ký tự")
        String name,

        String description,

        String qrCode
) {
}
