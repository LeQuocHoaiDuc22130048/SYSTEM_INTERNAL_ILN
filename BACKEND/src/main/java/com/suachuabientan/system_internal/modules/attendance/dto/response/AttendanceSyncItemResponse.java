package com.suachuabientan.system_internal.modules.attendance.dto.response;

import java.util.UUID;

public record AttendanceSyncItemResponse(
        String localLogId,
        String status,
        UUID serverRecordId,
        String message
) {
}

