package com.suachuabientan.system_internal.modules.employee.dto.response;

import java.time.LocalDate;

public record EmployeeStatsResponse(
        LocalDate from,
        LocalDate to,

        // Đơn sửa chữa
        long totalOrders,        // Tổng đơn được assign
        long completedOrders,    // Số đơn hoàn thành
        long inProgressOrders,   // Đang xử lý
        long cancelledOrders,    // Đã huỷ
        Double completionRate,   // Tỷ lệ hoàn thành (%)

        // Thời gian trung bình (phút)
        Double avgRepairMinutes, // Thời gian sửa trung bình mỗi đơn

        // Chấm công
        long totalWorkDays,      // Số ngày làm việc
        long lateDays,           // Số ngày đi muộn
        long earlyLeaveDays,     // Số ngày về sớm
        Double avgWorkHours      // Số giờ làm trung bình mỗi ngày
) {
}
