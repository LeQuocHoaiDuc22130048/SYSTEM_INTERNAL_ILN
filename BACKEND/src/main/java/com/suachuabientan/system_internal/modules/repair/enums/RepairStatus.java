package com.suachuabientan.system_internal.modules.repair.enums;

public enum RepairStatus {
    PENDING,            // Chưa kiểm tra (Chờ xử lý)
    WAITING_FOR_CHECK,  // Chờ kiểm tra
    CHECKING,           // Đang kiểm tra
    CHECKED,            // Đã kiểm tra
    IN_PROGRESS,        // Đang sửa
    COMPLETED,          // Hoàn thành
    DELIVERED,          // Đã giao
    CANCELLED           // Đã hủy
}
