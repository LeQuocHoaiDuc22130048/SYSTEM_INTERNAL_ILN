package com.suachuabientan.system_internal.modules.warehouse.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateBoardItemRequest(
        @NotBlank(message = "Tên bo mạch không được để trống")
        @Size(max = 200, message = "Tên tối đa 200 kí tự")
        String name,

        @Size(max = 100, message = "Danh mục tối đa 100 ký tự")
        String category,

        String description,

        @Size(max = 100, message = "Vị trí tối đa 100 ký tự")
        String location
) {
}
