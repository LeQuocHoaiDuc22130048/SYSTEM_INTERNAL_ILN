package com.suachuabientan.system_internal.modules.employee.dto.response;

import java.time.Instant;
import java.util.UUID;

public record EmployeeDetailResponse(
        UUID id,
        String username,
        String fullName,
        String employeeCode,
        String department,
        String phone,
        String address,
        String role,
        String status,
        String avatarUrl,
        Boolean faceEnrolled,
        Instant approvedAt,
        Instant createdAt
) {
}
