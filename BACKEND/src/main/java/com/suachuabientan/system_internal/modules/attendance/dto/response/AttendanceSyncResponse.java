package com.suachuabientan.system_internal.modules.attendance.dto.response;

import java.util.List;

public record AttendanceSyncResponse(
        int total,
        int synced,
        int skipped,
        int failed,
        List<AttendanceSyncItemResponse> results
) {
}

