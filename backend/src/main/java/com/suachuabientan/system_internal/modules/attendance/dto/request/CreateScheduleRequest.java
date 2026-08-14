package com.suachuabientan.system_internal.modules.attendance.dto.request;

import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

public record CreateScheduleRequest(
        @NotNull UUID employeeId,
        @NotNull LocalDate workDate,
        @NotNull LocalTime shiftStart,
        @NotNull LocalTime shiftEnd,
        String note
) {
}
