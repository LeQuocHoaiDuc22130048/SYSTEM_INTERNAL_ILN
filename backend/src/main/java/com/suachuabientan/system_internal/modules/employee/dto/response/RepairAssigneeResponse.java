package com.suachuabientan.system_internal.modules.employee.dto.response;

import java.util.UUID;

public record RepairAssigneeResponse(UUID id, String username, String fullName, String employeeCode,
                                    String role, String status, String avatarUrl) { }
