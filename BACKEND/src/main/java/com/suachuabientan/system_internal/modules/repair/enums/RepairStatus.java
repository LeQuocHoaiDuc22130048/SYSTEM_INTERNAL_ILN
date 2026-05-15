package com.suachuabientan.system_internal.modules.repair.enums;

public enum RepairStatus {
    PENDING,        // Chờ phân công
    IN_PROGRESS,    // Đang sửa chữa
    COMPLETED,      // Đã sửa xong, chưa giao
    DELIVERED,      // Đã giao khách
    CANCELLED       // Đã huỷ
}
