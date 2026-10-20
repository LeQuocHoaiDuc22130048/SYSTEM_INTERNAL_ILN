package com.suachuabientan.system_internal.modules.customer.dto;

import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import java.time.Instant;
import java.util.UUID;

public record CustomerOrderResponse(
        UUID id,
        String orderCode,
        String deviceName,
        String deviceType,
        String serialNumber,
        RepairStatus status,
        String statusLabel,
        Instant receivedAt,
        Instant estimatedDone,
        Instant completedAt,
        Instant deliveredAt,
        int deviceCount
) {
    public static String getFriendlyStatusLabel(RepairStatus status) {
        if (status == null) return "Chưa xác định";
        return switch (status) {
            case PENDING -> "Đã tiếp nhận";
            case WAITING_FOR_CHECK -> "Chờ kiểm tra";
            case CHECKING -> "Đang kiểm tra & chuẩn đoán";
            case CHECKED -> "Đã kiểm tra (chờ linh kiện/duyệt)";
            case IN_PROGRESS -> "Đang tiến hành sửa chữa";
            case COMPLETED -> "Đã sửa xong & test thành công";
            case DELIVERED -> "Đã bàn giao cho khách";
            case CANCELLED -> "Đã trả thiết bị / Hủy đơn";
            default -> "Đang xử lý";
        };
    }
}
