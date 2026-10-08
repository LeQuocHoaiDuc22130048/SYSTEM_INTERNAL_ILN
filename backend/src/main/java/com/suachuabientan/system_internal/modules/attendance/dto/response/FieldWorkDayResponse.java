package com.suachuabientan.system_internal.modules.attendance.dto.response;
import java.time.*;
import java.util.UUID;
public record FieldWorkDayResponse(UUID id, UUID employeeId, LocalDate workDate, String note,
                                   Instant createdAt, Instant updatedAt) {}
