package com.suachuabientan.system_internal.modules.attendance.tablet;
import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;
import java.util.UUID;
@Entity @Table(name="attendance_tablets") @Getter @Setter @NoArgsConstructor
public class TabletDevice {
    @Id
    private UUID id;
    private UUID accountId;
    private String installationId;
    @com.fasterxml.jackson.annotation.JsonIgnore
    private String secretHash;
    private String name;
    private String status;
    private String model;
    private String osVersion;
    private String appVersion;
    private Instant lastSeenAt;
    private Instant lastSyncAt;
    private Instant createdAt;
    private int pendingCount;
    private long statusVersion;
}
