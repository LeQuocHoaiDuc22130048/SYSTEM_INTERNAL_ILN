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

        @Size(max = 100)
        String model,

        @Size(max = 100)
        String boardType,

        @Size(max = 50)
        String firmware,

        String removedParts,

        java.time.LocalDate receivedDate,

        String note,

        String partId,

        String currentLocationId,

        Integer quantity
) {
}

