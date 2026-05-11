package com.suachuabientan.system_internal.modules.warehouse.dto.request;

import com.suachuabientan.system_internal.modules.warehouse.enums.BoardStatus;
import jakarta.validation.constraints.Size;

public record UpdateBoardItemRequest(
        @Size(max = 200)
        String name,

        @Size(max = 100)
        String category,

        String description,

        @Size(max = 100)
        String location,

        BoardStatus status
) {
}
