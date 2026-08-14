package com.suachuabientan.system_internal.modules.attendance.dto.request;

import com.suachuabientan.system_internal.modules.attendance.enums.AttendanceType;
import jakarta.validation.constraints.NotNull;

import java.time.Instant;
import java.util.UUID;

public record ManualCheckinRequest(
        @NotNull UUID employeeId,
        @NotNull AttendanceType type,
        @NotNull Instant checkTime,
        String note
) {
}
