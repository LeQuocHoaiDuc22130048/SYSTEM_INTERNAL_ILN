package com.suachuabientan.system_internal.modules.repair.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

@Entity
@Table(name = "repair_orders")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RepairOrder extends BaseEntity {
    /**
     * Mã đơn — sinh tự động: RO-{YYYYMMDD}-{NNN}
     * VD: RO-20240115-001
     */
    @Column(name = "order_code", nullable = false, unique = true, length = 30)
    private String orderCode;

    // ── Thông tin thiết bị ────────────────────────────────────

    @Column(name = "device_name", nullable = false, length = 200)
    private String deviceName;

    /** VD: Laptop, Desktop, Màn hình, Máy in */
    @Column(name = "device_type", length = 100)
    private String deviceType;

    @Column(name = "serial_number", length = 100)
    private String serialNumber;

    @Column(name = "under_warranty")
    private Boolean underWarranty = false;

    // ── Thông tin khách hàng ──────────────────────────────────

    @Column(name = "customer_name", nullable = false, length = 100)
    private String customerName;

    @Column(name = "customer_phone", length = 20)
    private String customerPhone;

    @Column(columnDefinition = "TEXT")
    private String description;

    // ── Vòng đời đơn ─────────────────────────────────────────

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private RepairStatus status = RepairStatus.PENDING;

    /**
     * Độ ưu tiên — số nhỏ hơn = ưu tiên cao hơn.
     * Mặc định 100, Manager điều chỉnh qua drag & drop.
     */
    @Column(nullable = false)
    private Integer priority = 100;

    // ── Phân công ─────────────────────────────────────────────

    /** Người tiếp nhận đơn */
    @Column(name = "received_by", nullable = false)
    private UUID receivedBy;

    /** Kỹ thuật viên được assign — nullable khi mới tạo */
    @Column(name = "assigned_to")
    private UUID assignedTo;

    /** Danh sách kỹ thuật viên cùng tiếp nhận sửa chữa */
    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(
            name = "repair_order_assignees",
            joinColumns = @JoinColumn(name = "order_id")
    )
    @Column(name = "technician_id")
    @Builder.Default
    private Set<UUID> assignees = new HashSet<>();

    /** Danh sách thiết bị trong đơn — cascade ALL, orphanRemoval */
    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    private List<RepairDevice> devices = new ArrayList<>();

    // ── Mốc thời gian ─────────────────────────────────────────

    @Column(name = "received_at", nullable = false)
    private Instant receivedAt;

    @Column(name = "estimated_done")
    private Instant estimatedDone;

    @Column(name = "started_at")
    private Instant startedAt;

    @Column(name = "completed_at")
    private Instant completedAt;

    @Column(name = "delivered_at")
    private Instant deliveredAt;

    // ── Helper methods ────────────────────────────────────────

    public boolean isActive() {
        return status != RepairStatus.DELIVERED && status != RepairStatus.CANCELLED;
    }

    public boolean canTransitionTo(RepairStatus newStatus) {
        return true;
    }
}
