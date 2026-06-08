package com.suachuabientan.system_internal.modules.attendance.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "face_recognition_logs")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FaceRecognitionLog extends BaseEntity {
    @Column(name = "local_attempt_id", length = 160)
    private String localAttemptId;

    @Column(name = "employee_id")
    private UUID employeeId;

    @Column(name = "employee_name", length = 255)
    private String employeeName;

    @Column(name = "attempted_by")
    private UUID attemptedBy;

    @Column(name = "device_id", length = 120)
    private String deviceId;

    @Column(name = "model_name", nullable = false, length = 80)
    private String modelName;

    @Column(name = "source", nullable = false, length = 40)
    private String source;

    @Column(name = "outcome", nullable = false, length = 30)
    private String outcome;

    @Column(name = "similarity_score")
    private Double similarityScore;

    @Column(name = "threshold")
    private Double threshold;

    @Column(name = "occurred_at", nullable = false)
    private Instant occurredAt;
}
