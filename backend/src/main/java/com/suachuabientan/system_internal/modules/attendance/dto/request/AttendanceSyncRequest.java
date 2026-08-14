package com.suachuabientan.system_internal.modules.attendance.dto.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public record AttendanceSyncRequest(
        @NotEmpty List<@Valid AttendanceSyncItemRequest> logs
) {
}

