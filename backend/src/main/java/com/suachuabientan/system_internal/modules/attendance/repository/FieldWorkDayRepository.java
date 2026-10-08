package com.suachuabientan.system_internal.modules.attendance.repository;
import com.suachuabientan.system_internal.modules.attendance.entity.FieldWorkDay;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.*;
public interface FieldWorkDayRepository extends JpaRepository<FieldWorkDay, UUID> {
    Optional<FieldWorkDay> findByEmployeeIdAndWorkDate(UUID employeeId, LocalDate workDate);
    Optional<FieldWorkDay> findByEmployeeIdAndWorkDateAndIsDeletedFalse(UUID employeeId, LocalDate workDate);
    List<FieldWorkDay> findByEmployeeIdAndWorkDateBetweenAndIsDeletedFalseOrderByWorkDateAsc(UUID employeeId, LocalDate from, LocalDate to);
    List<FieldWorkDay> findByWorkDateBetweenAndIsDeletedFalse(LocalDate from, LocalDate to);
    List<FieldWorkDay> findByWorkDateAndIsDeletedFalse(LocalDate date);
}
