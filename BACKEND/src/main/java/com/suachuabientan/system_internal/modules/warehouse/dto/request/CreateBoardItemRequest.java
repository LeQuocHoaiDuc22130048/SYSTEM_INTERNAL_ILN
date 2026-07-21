package com.suachuabientan.system_internal.modules.warehouse.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateBoardItemRequest(
        @NotBlank(message = "Tên bo mạch không được để trống")
        String name,

        @Size(max = 255, message = "Danh mục tối đa 255 ký tự")
        String category,

        String description,

        @Size(max = 255, message = "Vị trí tối đa 255 ký tự")
        String location,

        @Size(max = 100)
        String serialNumber,

        String partId,

        String currentLocationId
) {
}
