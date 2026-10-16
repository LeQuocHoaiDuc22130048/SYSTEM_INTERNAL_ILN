package com.suachuabientan.system_internal.modules.attendance.tablet;
import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;
import java.util.UUID;
@Entity @Table(name="attendance_tablet_events") @Getter @Setter @NoArgsConstructor
public class TabletEvent {
    @Id
    private UUID id;
    private UUID deviceId;
    private UUID actorId;
    private String action;
    @Column(length=500)
    private String reason;
    private Instant occurredAt;
}
