package com.suachuabientan.system_internal.modules.attendance.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.Instant;
import java.util.UUID;

public record FaceRecognitionLogItemRequest(
        @NotBlank String localAttemptId,
        @NotBlank String modelName,
        @NotBlank String outcome,
        Double similarityScore,
        @NotNull Double threshold,
        UUID employeeId,
        String localEmployeeId,
        String employeeName,
        String deviceId,
        @NotNull Instant occurredAt
) {
}
