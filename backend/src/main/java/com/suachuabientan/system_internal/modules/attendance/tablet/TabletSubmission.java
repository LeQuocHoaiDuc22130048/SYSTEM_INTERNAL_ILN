package com.suachuabientan.system_internal.modules.attendance.tablet;
import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;
import java.util.UUID;
@Entity @Table(name="attendance_tablet_submissions") @Getter @Setter @NoArgsConstructor
public class TabletSubmission {
    @Id
    private UUID id;
    private UUID deviceId;
    private UUID accountId;
    private String localLogId;
    private String payloadHash;
    @Column(columnDefinition="text") @com.fasterxml.jackson.annotation.JsonIgnore
    private String payload;
    private String status;
    @Column(length=500)
    private String error;
    private UUID recordId;
    private UUID employeeId;
    private Instant capturedAt;
    private String attendanceType;
    private UUID reviewedBy;
    @Column(length=500)
    private String reason;
    private Instant createdAt;
    private Instant reviewedAt;
}
