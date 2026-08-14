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

import java.time.LocalDate;

@Entity
@Table(name = "face_recognition_daily_alerts")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FaceRecognitionDailyAlert extends BaseEntity {
    @Column(name = "metric_date", nullable = false)
    private LocalDate metricDate;

    @Column(name = "false_reject_rate", nullable = false)
    private Double falseRejectRate;

    @Column(name = "rejected_count", nullable = false)
    private Long rejectedCount;

    @Column(name = "total_count", nullable = false)
    private Long totalCount;
}
