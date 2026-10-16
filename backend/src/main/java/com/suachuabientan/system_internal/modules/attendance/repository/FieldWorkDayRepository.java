package com.suachuabientan.system_internal.modules.attendance.repository;
import com.suachuabientan.system_internal.modules.attendance.entity.FieldWorkDay;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import java.time.LocalDate;
import java.util.*;
public interface FieldWorkDayRepository extends JpaRepository<FieldWorkDay, UUID> {
    Optional<FieldWorkDay> findByEmployeeIdAndWorkDate(UUID employeeId, LocalDate workDate);
    // Attendance totals must only include approved requests.
    @Query("select d from FieldWorkDay d where d.employeeId = :employeeId and d.workDate = :workDate and d.isDeleted = false and d.status = 'APPROVED'")
    Optional<FieldWorkDay> findByEmployeeIdAndWorkDateAndIsDeletedFalse(UUID employeeId, LocalDate workDate);
    @Query("select d from FieldWorkDay d where d.employeeId = :employeeId and d.workDate between :from and :to and d.isDeleted = false and d.status = 'APPROVED' order by d.workDate")
    List<FieldWorkDay> findByEmployeeIdAndWorkDateBetweenAndIsDeletedFalseOrderByWorkDateAsc(UUID employeeId, LocalDate from, LocalDate to);
    @Query("select d from FieldWorkDay d where d.workDate between :from and :to and d.isDeleted = false and d.status = 'APPROVED'")
    List<FieldWorkDay> findByWorkDateBetweenAndIsDeletedFalse(LocalDate from, LocalDate to);
    @Query("select d from FieldWorkDay d where d.workDate = :date and d.isDeleted = false and d.status = 'APPROVED'")
    List<FieldWorkDay> findByWorkDateAndIsDeletedFalse(LocalDate date);
    List<FieldWorkDay> findByEmployeeIdAndWorkDateBetweenAndIsDeletedFalseOrderByWorkDateDesc(UUID employeeId, LocalDate from, LocalDate to);
    List<FieldWorkDay> findTop100ByStatusAndIsDeletedFalseOrderByCreatedAtAsc(String status);
}
