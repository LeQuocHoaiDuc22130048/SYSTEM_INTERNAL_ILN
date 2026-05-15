package com.suachuabientan.system_internal.modules.repair.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "repair_timeline")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RepairTimeline {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "order_id", nullable = false)
    private UUID orderId;

    /**
     * Các action chuẩn:
     *   Tiếp nhận đơn | Phân công kỹ thuật viên | Thay đổi ưu tiên
     *   Bắt đầu sửa chữa | Upload ảnh | Hoàn thành sửa chữa
     *   Giao hàng cho khách | Huỷ đơn
     */
    @Column(nullable = false, length = 100)
    private String action;

    @Column(columnDefinition = "TEXT")
    private String note;

    @Column(name = "performed_by", nullable = false)
    private UUID performedBy;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "created_by")
    private UUID createdBy;
}
