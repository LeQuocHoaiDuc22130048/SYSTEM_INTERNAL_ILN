package com.suachuabientan.system_internal.modules.warehouse.dto.response;

import java.util.UUID;

public record CategoryInfo(
        UUID id,
        String name,
        String description
) {
}
