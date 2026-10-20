package com.suachuabientan.system_internal.modules.repair.dto.response;

import java.time.Instant;
import java.util.UUID;

public record RepairTimelineResponse(
        UUID id,
        String action,
        String note,
        Instant createdAt,
        PerformerInfo performedBy,
        String status,
        String changedByName,
        Instant changedAt
) {
    public RepairTimelineResponse(UUID id, String action, String note, Instant createdAt, PerformerInfo performedBy) {
        this(
                id,
                action,
                note,
                createdAt,
                performedBy,
                action,
                performedBy != null ? performedBy.fullName() : "Hệ thống",
                createdAt
        );
    }

    public record PerformerInfo(
            UUID id,
            String fullName,
            String employeeCode,
            String avatarUrl
    ) {
    }
}

