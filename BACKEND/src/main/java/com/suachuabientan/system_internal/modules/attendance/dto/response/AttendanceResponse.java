package com.suachuabientan.system_internal.modules.attendance.dto.response;

import java.time.Instant;
import java.util.UUID;

/**
 * Response sau khi chấm công thành công.
 * Flutter dùng để hiển thị popup kết quả.
 */
public record AttendanceResponse(
        UUID id,
        UUID employeeId,
        String employeeName,
        String employeeCode,
        String avatarUrl,
        String type,            // IN | OUT
        Instant checkTime,
        Double confidenceScore,
        String faceImagePath,
        Boolean isValid,
        String note
) {
}
