package com.suachuabientan.system_internal.modules.repair.dto.request;

import java.util.List;
import java.util.UUID;

public record AssignRequest(
        UUID technicianId,
        List<UUID> technicianIds,
        String note
) {
}
