package com.suachuabientan.system_internal.modules.mediacleanup.entity;

import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupJobStatus;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupTriggerType;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "media_cleanup_jobs")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MediaCleanupJob {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "job_code", nullable = false, unique = true, length = 60)
    private String jobCode;

    @Enumerated(EnumType.STRING)
    @Column(name = "trigger_type", nullable = false, length = 30)
    private CleanupTriggerType triggerType;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    @Builder.Default
    private CleanupJobStatus status = CleanupJobStatus.RUNNING;

    @Column(name = "instance_id", nullable = false, length = 150)
    private String instanceId;

    @Column(name = "batch_size", nullable = false)
    @Builder.Default
    private int batchSize = 100;

    @Column(name = "total_batches", nullable = false)
    @Builder.Default
    private int totalBatches = 0;

    @Column(name = "total_processed", nullable = false)
    @Builder.Default
    private int totalProcessed = 0;

    @Column(name = "deleted_count", nullable = false)
    @Builder.Default
    private int deletedCount = 0;

    @Column(name = "failed_count", nullable = false)
    @Builder.Default
    private int failedCount = 0;

    @Column(name = "skipped_count", nullable = false)
    @Builder.Default
    private int skippedCount = 0;

    @Column(name = "freed_bytes", nullable = false)
    @Builder.Default
    private long freedBytes = 0L;

    @Column(name = "started_at", nullable = false, updatable = false)
    @Builder.Default
    private Instant startedAt = Instant.now();

    @Column(name = "last_heartbeat_at", nullable = false)
    @Builder.Default
    private Instant lastHeartbeatAt = Instant.now();

    @Column(name = "finished_at")
    private Instant finishedAt;

    @Column(name = "error_summary", columnDefinition = "TEXT")
    private String errorSummary;

    @PrePersist
    public void onPrePersist() {
        Instant now = Instant.now();
        if (this.startedAt == null) {
            this.startedAt = now;
        }
        if (this.lastHeartbeatAt == null) {
            this.lastHeartbeatAt = now;
        }
    }
}

