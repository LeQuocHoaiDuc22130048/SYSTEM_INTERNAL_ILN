package com.suachuabientan.system_internal.modules.attendance.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import com.suachuabientan.system_internal.modules.attendance.enums.AttendanceType;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "attendance_records")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AttendanceRecord extends BaseEntity {
    @Column(name = "employee_id", nullable = false)
    private UUID employeeId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 5)
    private AttendanceType type;

    @Column(name = "check_time", nullable = false)
    private Instant checkTime;

    /** Đường dẫn ảnh chấm công lưu trên MinIO */
    @Column(name = "face_image_path", length = 500)
    private String faceImagePath;

    /** Độ chính xác nhận diện khuôn mặt 0.0000 → 1.0000 */
    @Column(name = "confidence_score")
    private Double confidenceScore;

    /** ID tablet chấm công */
    @Column(name = "device_id", length = 100)
    private String deviceId;

    /** FALSE nếu admin huỷ bản ghi */
    @Column(name = "is_valid", nullable = false)
    private Boolean isValid = true;

    /** Ghi chú nếu chấm tay (override) */
    @Column(columnDefinition = "TEXT")
    private String note;
}
