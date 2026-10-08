package com.suachuabientan.system_internal.modules.attendance.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.modules.attendance.entity.FieldWorkDay;
import com.suachuabientan.system_internal.modules.attendance.repository.FieldWorkDayRepository;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.attendance.dto.response.FieldWorkDayResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
import java.util.*;

@Service
@RequiredArgsConstructor
public class FieldWorkService {
    private static final ZoneId ZONE = ZoneId.of("Asia/Ho_Chi_Minh");
    private final FieldWorkDayRepository days;
    private final UserRepository users;

    @Transactional
    public FieldWorkDayResponse save(UUID employeeId, LocalDate date, String note) {
        validateDate(date);
        if (note == null || note.isBlank() || note.strip().length() > 2000) {
            throw new BusinessException("Ghi chú đi công trình phải có nội dung và không quá 2000 ký tự");
        }
        requireEmployeeForUpdate(employeeId);
        FieldWorkDay day = days.findByEmployeeIdAndWorkDate(employeeId, date).orElseGet(() -> {
            FieldWorkDay created = new FieldWorkDay();
            created.setEmployeeId(employeeId);
            created.setWorkDate(date);
            created.setCreatedBy(employeeId);
            return created;
        });
        day.setNote(note.strip());
        day.setIsDeleted(false);
        day.setDeletedAt(null);
        day.setUpdatedBy(employeeId);
        return toResponse(days.save(day));
    }

    @Transactional
    public void remove(UUID employeeId, LocalDate date) {
        validateDate(date);
        requireEmployeeForUpdate(employeeId);
        days.findByEmployeeIdAndWorkDate(employeeId, date)
                .filter(day -> !Boolean.TRUE.equals(day.getIsDeleted()))
                .ifPresent(day -> {
                    day.softDelete(employeeId);
                    days.save(day);
                });
    }

    @Transactional(readOnly = true)
    public List<FieldWorkDayResponse> list(UUID employeeId, LocalDate from, LocalDate to) {
        requireEmployee(employeeId);
        LocalDate end = to != null ? to : LocalDate.now(ZONE);
        LocalDate start = from != null ? from : end.withDayOfMonth(1);
        if (end.isBefore(start)) {
            throw new BusinessException("Ngày kết thúc phải sau hoặc bằng ngày bắt đầu");
        }
        return days.findByEmployeeIdAndWorkDateBetweenAndIsDeletedFalseOrderByWorkDateAsc(employeeId, start, end)
                .stream().map(FieldWorkService::toResponse).toList();
    }

    private void requireEmployeeForUpdate(UUID employeeId) {
        users.findForFieldWorkUpdate(employeeId)
                .orElseThrow(() -> new BusinessException("Không tìm thấy nhân viên"));
    }

    private void requireEmployee(UUID employeeId) {
        users.findByIdAndIsDeletedFalse(employeeId)
                .orElseThrow(() -> new BusinessException("Không tìm thấy nhân viên"));
    }

    private void validateDate(LocalDate date) {
        if (date == null || date.isAfter(LocalDate.now(ZONE))) {
            throw new BusinessException("Ngày đi công trình phải là hôm nay hoặc ngày trước đó");
        }
    }

    public static FieldWorkDayResponse toResponse(FieldWorkDay day) {
        return new FieldWorkDayResponse(day.getId(), day.getEmployeeId(), day.getWorkDate(),
                day.getNote(), day.getCreatedAt(), day.getUpdatedAt());
    }

    public static String displayNote(FieldWorkDay day) {
        return "Đi công trình — " + day.getNote();
    }
}

