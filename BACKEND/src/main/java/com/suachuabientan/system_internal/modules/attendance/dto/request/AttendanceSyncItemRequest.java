package com.suachuabientan.system_internal.modules.attendance.dto.request;

import com.suachuabientan.system_internal.modules.attendance.enums.AttendanceType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record AttendanceSyncItemRequest(
        @NotBlank String localLogId,
        @NotNull UUID employeeId,
        @NotNull AttendanceType type,
        @NotNull Instant checkTime,
        Instant mobileCheckTime,
        Double confidenceScore,
        List<Double> faceEmbedding,
        String faceImageBase64,
        String imageContentType,
        String deviceId,
        String note
) {
}
