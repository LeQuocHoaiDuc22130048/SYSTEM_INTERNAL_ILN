package com.suachuabientan.system_internal.modules.mediacleanup.entity;

import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupLogAction;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupLogOutcome;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "media_cleanup_logs")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MediaCleanupLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "job_id", nullable = false)
    private UUID jobId;

    @Column(name = "media_id", nullable = false)
    private UUID mediaId;

    @Column(name = "bucket_name", nullable = false, length = 100)
    private String bucketName;

    @Column(name = "object_key", nullable = false, length = 500)
    private String objectKey;

    @Column(name = "file_size", nullable = false)
    @Builder.Default
    private long fileSize = 0L;

    @Enumerated(EnumType.STRING)
    @Column(name = "action", nullable = false, length = 40)
    private CleanupLogAction action;

    @Enumerated(EnumType.STRING)
    @Column(name = "outcome", nullable = false, length = 20)
    private CleanupLogOutcome outcome;

    @Column(name = "attempt_number", nullable = false)
    @Builder.Default
    private int attemptNumber = 1;

    @Column(name = "duration_ms", nullable = false)
    @Builder.Default
    private long durationMs = 0L;

    @Column(name = "error_code", length = 100)
    private String errorCode;

    @Column(name = "error_message", columnDefinition = "TEXT")
    private String errorMessage;

    @Column(name = "created_at", nullable = false, updatable = false)
    @Builder.Default
    private Instant createdAt = Instant.now();

    @PrePersist
    public void onPrePersist() {
        if (this.createdAt == null) {
            this.createdAt = Instant.now();
        }
    }
}

