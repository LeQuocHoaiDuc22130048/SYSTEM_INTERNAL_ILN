package com.suachuabientan.system_internal.modules.auth.dto.response;


import java.time.Instant;
import java.util.UUID;

public record UserResponse (
        UUID id,
        String username,
        String fullName,
        String employeeCode,
        String department,
        String phone,
        String role,
        String status,
        String avatarUrl,
        Boolean faceEnrolled,
        Instant approvedAt,
        Instant createdAt
) {}
