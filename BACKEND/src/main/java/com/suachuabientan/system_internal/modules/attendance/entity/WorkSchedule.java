package com.suachuabientan.system_internal.modules.attendance.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

@Entity
@Table(name = "work_schedules",
        uniqueConstraints = @UniqueConstraint(columnNames = {"employee_id", "work_date"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class WorkSchedule extends BaseEntity {
    @Column(name = "employee_id", nullable = false)
    private UUID employeeId;

    @Column(name = "work_date", nullable = false)
    private LocalDate workDate;

    @Column(name = "shift_start", nullable = false)
    private LocalTime shiftStart;

    @Column(name = "shift_end", nullable = false)
    private LocalTime shiftEnd;

    @Column(columnDefinition = "TEXT")
    private String note;
}
