package com.suachuabientan.system_internal.modules.attendance.tablet;
import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;
import java.util.UUID;
@Entity @Table(name="attendance_tablet_leases") @Getter @Setter @NoArgsConstructor
public class TabletLease {
    @Id
    private UUID id;
    private UUID deviceId;
    private UUID accountId;
    private Instant issuedAt;
    private Instant expiresAt;
    private long statusVersion;
    @com.fasterxml.jackson.annotation.JsonIgnore
    private String signature;
}
