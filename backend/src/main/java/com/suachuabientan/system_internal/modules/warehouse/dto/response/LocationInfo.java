package com.suachuabientan.system_internal.modules.warehouse.dto.response;

import java.util.UUID;

public record LocationInfo(
        UUID id,
        String code,
        String name
) {
}
