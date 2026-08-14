package com.suachuabientan.system_internal.modules.attendance.dto.response;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

public record WorkScheduleResponse(
        UUID id,
        UUID employeeId,
        String employeeName,
        LocalDate workDate,
        LocalTime shiftStart,
        LocalTime shiftEnd,
        String note
) {
}
