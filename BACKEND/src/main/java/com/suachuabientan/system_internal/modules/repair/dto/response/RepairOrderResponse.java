package com.suachuabientan.system_internal.modules.repair.dto.response;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record RepairOrderResponse(
        UUID id,
        String orderCode,

        // Thông tin thiết bị đầu tiên (backward compat)
        String deviceName,
        String deviceType,
        String serialNumber,

        // Khách hàng
        String customerName,
        String customerPhone,
        String description,

        // Vòng đời
        String status,
        Integer priority,

        // Phân công
        UserSummary receivedBy,
        UserSummary assignedTo,
        List<UserSummary> assignees,

        // Thời gian
        Instant receivedAt,
        Instant estimatedDone,
        Instant startedAt,
        Instant completedAt,
        Instant deliveredAt,

        Boolean underWarranty,

        // Đính kèm
        List<ImageInfo> images,

        Instant createdAt,

        // Danh sách thiết bị trong đơn
        List<RepairDeviceResponse> devices,
        String notes
) {
    public record UserSummary(
            UUID id,
            String fullName,
            String employeeCode,
            String avatarUrl
    ) {
    }

    public record ImageInfo(
            UUID id,
            String imageUrl,
            String mediaType,
            String caption,
            Instant uploadedAt
    ) {
    }
}
