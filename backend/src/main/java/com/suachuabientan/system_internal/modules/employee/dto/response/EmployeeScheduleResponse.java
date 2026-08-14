package com.suachuabientan.system_internal.modules.employee.dto.response;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record EmployeeScheduleResponse(
        LocalDate date,
        List<RepairActivity> repairActivities,
        AttendanceSummary attendance
) {
    public record RepairActivity(
            UUID orderId,
            String orderCode,
            String deviceName,
            String customerName,
            String status,
            Instant receivedAt,
            Instant completedAt
    ) {}

    public record AttendanceSummary(
            Instant checkIn,
            Instant checkOut,
            Long totalMinutes
    ) {}
}
