package com.suachuabientan.system_internal.modules.repair.dto.response;

import java.time.Instant;
import java.util.UUID;

public record RepairTimelineResponse(
        UUID id,
        String action,
        String note,
        Instant createdAt,
        PerformerInfo performedBy
) {
    public record PerformerInfo(
            UUID id,
            String fullName,
            String employeeCode,
            String avatarUrl
    ) {
    }
}
