package com.suachuabientan.system_internal.modules.attendance.dto.response;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

/**
 * Tổng hợp chấm công theo ngày của một nhân viên.
 * Dùng cho màn hình lịch sử và báo cáo.
 */
public record DailyAttendanceResponse(
        LocalDate date,
        Instant checkIn,        // Giờ vào đầu tiên trong ngày
        Instant checkOut,       // Giờ ra cuối cùng trong ngày
        Long totalMinutes,      // Tổng thời gian làm (phút)
        Boolean isLate,         // Đi muộn so với lịch
        Boolean isEarlyLeave,   // Về sớm so với lịch
        String shiftStart,      // Ca làm việc quy định
        String shiftEnd,
        List<AttendanceResponse> records  // Toàn bộ bản ghi trong ngày
) {
}
