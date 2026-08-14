package com.suachuabientan.system_internal.modules.attendance.dto.request;

import jakarta.validation.constraints.NotNull;
import java.time.Instant;

public record UpdateAttendanceRecordRequest(
        @NotNull Instant checkTime,
        Boolean isValid,
        String note
) {
}
