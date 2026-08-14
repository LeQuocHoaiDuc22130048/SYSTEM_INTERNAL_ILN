package com.suachuabientan.system_internal.modules.attendance.repository;

import com.suachuabientan.system_internal.modules.attendance.entity.WorkSchedule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface WorkScheduleRepository extends JpaRepository<WorkSchedule, UUID> {
    Optional<WorkSchedule> findByEmployeeIdAndWorkDateAndIsDeletedFalse(
            UUID employeeId, LocalDate workDate);

    /**
     * Lịch làm việc của nhân viên trong khoảng ngày.
     */
    @Query("""
            SELECT w FROM WorkSchedule w
            WHERE w.employeeId = :employeeId
              AND w.workDate BETWEEN :from AND :to
              AND w.isDeleted = false
            ORDER BY w.workDate ASC
            """)
    List<WorkSchedule> findByEmployeeAndDateRange(
            @Param("employeeId") UUID employeeId,
            @Param("from") LocalDate from,
            @Param("to") LocalDate to);

    List<WorkSchedule> findByWorkDateAndIsDeletedFalse(LocalDate workDate);

    @Query("""
            SELECT w FROM WorkSchedule w
            WHERE w.workDate >= :startDate
              AND w.workDate <= :endDate
              AND w.isDeleted = false
            """)
    List<WorkSchedule> findByWorkDateBetween(
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate);
}

