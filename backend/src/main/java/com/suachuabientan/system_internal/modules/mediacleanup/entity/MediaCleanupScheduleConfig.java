package com.suachuabientan.system_internal.modules.mediacleanup.entity;

import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupScheduleMode;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "media_cleanup_schedule_config")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MediaCleanupScheduleConfig {

    @Id
    @Column(name = "id")
    @Builder.Default
    private Integer id = 1;

    @Column(name = "is_enabled", nullable = false)
    @Builder.Default
    private boolean enabled = false;

    @Enumerated(EnumType.STRING)
    @Column(name = "schedule_mode", nullable = false, length = 30)
    @Builder.Default
    private CleanupScheduleMode scheduleMode = CleanupScheduleMode.SPECIFIC_DATETIME;

    @Column(name = "scheduled_run_at")
    private Instant scheduledRunAt;

    @Column(name = "day_of_month")
    @Builder.Default
    private Integer dayOfMonth = 1;

    @Column(name = "day_of_week")
    @Builder.Default
    private Integer dayOfWeek = 1;

    @Column(name = "time_of_day", nullable = false, length = 10)
    @Builder.Default
    private String timeOfDay = "02:00";

    @Column(name = "unreferenced_upload_ttl_hours", nullable = false)
    @Builder.Default
    private long unreferencedUploadTtlHours = 24;

    @Column(name = "deleted_message_media_ttl_days", nullable = false)
    @Builder.Default
    private long deletedMessageMediaTtlDays = 7;

    @Column(name = "closed_repair_media_ttl_days", nullable = false)
    @Builder.Default
    private long closedRepairMediaTtlDays = 180;

    @Column(name = "last_triggered_at")
    private Instant lastTriggeredAt;

    @Column(name = "updated_by", length = 100)
    private String updatedBy;

    @Column(name = "updated_at", nullable = false)
    @Builder.Default
    private Instant updatedAt = Instant.now();

    @PrePersist
    @PreUpdate
    public void onSave() {
        this.updatedAt = Instant.now();
    }
}

