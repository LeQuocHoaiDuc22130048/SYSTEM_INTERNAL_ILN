package com.suachuabientan.system_internal.modules.attendance.entity;
import com.suachuabientan.system_internal.common.model.BaseEntity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.time.LocalDate;
import java.util.UUID;
@Entity
@Table(name = "field_work_days", uniqueConstraints = @UniqueConstraint(columnNames = {"employee_id", "work_date"}))
@Getter @Setter
public class FieldWorkDay extends BaseEntity {
    @Column(nullable = false, length = 20) private String status = "PENDING";
    @Column(name = "reviewed_by") private UUID reviewedBy;
    @Column(name = "reviewed_at") private java.time.Instant reviewedAt;
    @Version private Long version;
    @Column(name = "employee_id", nullable = false) private UUID employeeId;
    @Column(name = "work_date", nullable = false) private LocalDate workDate;
    @Column(nullable = false, length = 2000) private String note;
}
