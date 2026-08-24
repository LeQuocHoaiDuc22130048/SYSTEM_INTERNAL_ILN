package com.suachuabientan.system_internal.modules.warehouse.dto.request;

import com.suachuabientan.system_internal.modules.warehouse.enums.BoardStatus;
import jakarta.validation.constraints.Size;

import java.util.UUID;

public record UpdateBoardItemRequest(
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

        BoardStatus status,

        Integer quantity,

        Integer minQuantity
) {
}

