package com.suachuabientan.system_internal.modules.customer.dto;

import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import java.time.Instant;
import java.util.UUID;

public record CustomerOrderResponse(
        UUID id,
        String orderCode,
        String orderTitle,
        String deviceName,
        String deviceType,
        String serialNumber,
        String description,
        RepairStatus status,
        String statusLabel,
        String friendlyStatus,
        Instant receivedAt,
        Instant receivedDate,
        Instant estimatedDone,
        Instant expectedDeliveryDate,
        Instant completedAt,
        Instant deliveredAt,
        int deviceCount,
        int devicesCount
) {
    public CustomerOrderResponse(
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
        this(
                id,
                orderCode,
                buildOrderTitle(deviceName, deviceType, null),
                deviceName,
                deviceType,
                serialNumber,
                null,
                status,
                statusLabel,
                statusLabel,
                receivedAt,
                receivedAt,
                estimatedDone,
                estimatedDone,
                completedAt,
                deliveredAt,
                deviceCount,
                deviceCount
        );
    }

    public static String buildOrderTitle(String deviceName, String deviceType, String description) {
        String name = deviceName != null ? deviceName.strip() : "";
        String type = deviceType != null ? deviceType.strip() : "";
        if (!name.isEmpty()) {
            if (!type.isEmpty() && !name.toLowerCase().contains(type.toLowerCase())) {
                return name + " (" + type + ")";
            }
            return name;
        }
        if (!type.isEmpty()) {
            return type;
        }
        if (description != null && !description.isBlank()) {
            return description.strip();
        }
        return "Đơn sửa chữa thiết bị";
    }

    public static String getFriendlyStatusLabel(RepairStatus status) {
        if (status == null) return "Chưa xác định";
        return switch (status) {
            case PENDING -> "Đã tiếp nhận";
            case WAITING_FOR_CHECK -> "Chờ kiểm tra";
            case CHECKING -> "Đang kiểm tra & chẩn đoán";
            case CHECKED -> "Đã kiểm tra (chờ linh kiện/duyệt)";
            case IN_PROGRESS -> "Đang tiến hành sửa chữa";
            case COMPLETED -> "Đã sửa xong & kiểm tra thành công";
            case DELIVERED -> "Đã bàn giao cho khách";
            case CANCELLED -> "Đã trả thiết bị / Hủy đơn";
            default -> "Đang xử lý";
        };
    }
}
