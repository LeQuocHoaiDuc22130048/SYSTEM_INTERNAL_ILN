package com.suachuabientan.system_internal.modules.attendance.repository;

import com.suachuabientan.system_internal.modules.attendance.entity.AttendanceRecord;
import com.suachuabientan.system_internal.modules.attendance.enums.AttendanceType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface AttendanceRecordRepository extends JpaRepository<AttendanceRecord, UUID> {

    /**
     * Bản ghi chấm công cuối cùng của nhân viên trong ngày.
     * Dùng để xác định lần chấm tiếp theo là IN hay OUT.
     */
    @Query("""
            SELECT a FROM AttendanceRecord a
            WHERE a.employeeId = :employeeId
              AND a.checkTime >= :dayStart
              AND a.checkTime < :dayEnd
              AND a.isDeleted = false
            ORDER BY a.checkTime DESC
            """)
    List<AttendanceRecord> findTodayRecords(@Param("employeeId") UUID employeeId, @Param("dayStart") Instant dayStart, @Param("dayEnd") Instant dayEnd);

    /**
     * Lịch sử chấm công theo khoảng thời gian — phân trang.
     */
    @Query(value = """
            SELECT * FROM attendance_records a
            WHERE a.employee_id = :employeeId
              AND a.is_deleted = false
              AND a.check_time >= :from
              AND a.check_time < :to
            ORDER BY a.check_time DESC
            """, countQuery = """
            SELECT COUNT(*) FROM attendance_records a
            WHERE a.employee_id = :employeeId
              AND a.is_deleted = false
              AND a.check_time >= :from
              AND a.check_time < :to
            """, nativeQuery = true)
    Page<AttendanceRecord> findByEmployeeAndDateRange(@Param("employeeId") UUID employeeId, @Param("from") Instant from, @Param("to") Instant to, Pageable pageable);

    /**
     * Báo cáo toàn bộ nhân viên trong ngày — Manager xem.
     */
    @Query(value = """
            SELECT * FROM attendance_records a
            WHERE a.is_deleted = false
              AND a.check_time >= :dayStart
              AND a.check_time < :dayEnd
            ORDER BY a.check_time ASC
            """, nativeQuery = true)
    List<AttendanceRecord> findAllByDate(@Param("dayStart") Instant dayStart, @Param("dayEnd") Instant dayEnd);

    /**
     * Kiểm tra nhân viên đã check-in hôm nay chưa.
     */
    @Query("""
            SELECT COUNT(a) > 0 FROM AttendanceRecord a
            WHERE a.employeeId = :employeeId
              AND a.type = :type
              AND a.checkTime >= :dayStart
              AND a.checkTime < :dayEnd
              AND a.isDeleted = false
              AND a.isValid = true
            """)
    boolean existsByEmployeeAndTypeToday(@Param("employeeId") UUID employeeId, @Param("type") AttendanceType type, @Param("dayStart") Instant dayStart, @Param("dayEnd") Instant dayEnd);

    Optional<AttendanceRecord> findByDeviceLogIdAndIsDeletedFalse(String deviceLogId);

    boolean existsByEmployeeIdAndCheckTimeAndTypeAndIsDeletedFalse(UUID employeeId, Instant checkTime, AttendanceType type);

    @Query(value = """
            SELECT * FROM attendance_records a
            WHERE a.employee_id = :employeeId
              AND a.type = :type
              AND a.is_deleted = false
              AND a.is_valid = true
              AND COALESCE(a.mobile_check_time, a.check_time) >= :from
              AND COALESCE(a.mobile_check_time, a.check_time) <= :to
            ORDER BY a.check_time ASC
            """, nativeQuery = true)
    List<AttendanceRecord> findDedupCandidates(
            @Param("employeeId") UUID employeeId,
            @Param("type") String type,
            @Param("from") Instant from,
            @Param("to") Instant to);

    @Query("""
            SELECT a FROM AttendanceRecord a
            WHERE a.checkTime >= :start
              AND a.checkTime < :end
              AND a.isDeleted = false
              AND a.isValid = true
            ORDER BY a.checkTime ASC
            """)
    List<AttendanceRecord> findByCheckTimeBetween(
            @Param("start") Instant start,
            @Param("end") Instant end);

    @Query("""
            SELECT a FROM AttendanceRecord a
            WHERE a.employeeId = :employeeId
              AND a.checkTime >= :start
              AND a.checkTime < :end
              AND a.isDeleted = false
              AND a.isValid = true
            ORDER BY a.checkTime ASC
            """)
    List<AttendanceRecord> findByEmployeeIdAndCheckTimeBetween(
            @Param("employeeId") UUID employeeId,
            @Param("start") Instant start,
            @Param("end") Instant end);
}
