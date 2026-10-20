package com.suachuabientan.system_internal.modules.repair.dto.request;

import jakarta.validation.constraints.NotNull;
import java.util.UUID;

public record PublishCustomerMediaRequest(
        @NotNull(message = "ID hình ảnh/video không được để trống")
        UUID mediaId,

        String caption
) {
}
