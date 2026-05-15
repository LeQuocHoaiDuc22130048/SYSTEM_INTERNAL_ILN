package com.suachuabientan.system_internal.modules.repair.dto.response;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record RepairOrderResponse(
        UUID id,
        String orderCode,

        // Thiết bị
        String deviceName,
        String deviceType,

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

        // Thời gian
        Instant receivedAt,
        Instant estimatedDone,
        Instant startedAt,
        Instant completedAt,
        Instant deliveredAt,

        // Đính kèm
        List<ImageInfo> images,

        Instant createdAt
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
            String caption,
            Instant uploadedAt
    ) {
    }
}
