package com.suachuabientan.system_internal.modules.employee.dto.response;

import java.time.Instant;
import java.util.UUID;

public record EmployeeFaceEmbeddingResponse(
        UUID employeeId,
        String employeeCode,
        String fullName,
        String modelName,
        String embedding,
        Instant updatedAt
) {
}

