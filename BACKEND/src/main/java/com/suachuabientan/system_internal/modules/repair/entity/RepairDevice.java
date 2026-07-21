package com.suachuabientan.system_internal.modules.repair.entity;

import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "repair_devices")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RepairDevice {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "order_id", nullable = false)
    private RepairOrder order;

    @Column(name = "device_name", nullable = false, length = 200)
    private String deviceName;

    @Column(name = "device_type", length = 100)
    private String deviceType;

    @Column(name = "serial_number", length = 100)
    private String serialNumber;

    @Column(name = "under_warranty", nullable = false)
    @Builder.Default
    private Boolean underWarranty = false;

    @Column(name = "warranty_expiry")
    private java.time.LocalDate warrantyExpiry;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private RepairStatus status = RepairStatus.PENDING;

    /** Kỹ thuật viên phụ trách thiết bị này */
    @Column(name = "assigned_to")
    private UUID assignedTo;

    @Column(nullable = false)
    @Builder.Default
    private Integer priority = 100;

    @Column(name = "created_at", nullable = false)
    @Builder.Default
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at")
    private Instant updatedAt;
}
