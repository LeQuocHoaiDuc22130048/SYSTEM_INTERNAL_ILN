package com.suachuabientan.system_internal.modules.device.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import com.suachuabientan.system_internal.modules.device.enums.DeviceStatus;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "devices")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DeviceEntity extends BaseEntity {

    @Column(name = "device_id", nullable = false, unique = true, length = 100)
    private String deviceId;

    @Column(nullable = false, length = 150)
    private String name;

    @Column(nullable = false, length = 50)
    private String type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private DeviceStatus status = DeviceStatus.OFFLINE;

    @Column(name = "ip_address", nullable = false, length = 45)
    private String ipAddress;

    @Column(name = "port")
    private Integer port;

    @Column(name = "last_active_at")
    private Instant lastActiveAt;

    @Column(name = "ping_ms")
    @Builder.Default
    private Integer pingMs = 0;

    @Column(length = 20)
    @Builder.Default
    private String version = "1.0.0";
}
