package com.suachuabientan.system_internal.modules.attendance.dto.request;

public record CheckinRequest(
        String deviceId,
        String note
) {
}
