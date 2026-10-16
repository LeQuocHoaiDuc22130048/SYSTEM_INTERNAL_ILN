package com.suachuabientan.system_internal.modules.attendance.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.modules.attendance.entity.FieldWorkDay;
import com.suachuabientan.system_internal.modules.attendance.repository.FieldWorkDayRepository;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.attendance.dto.response.FieldWorkDayResponse;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
import java.util.*;
import java.util.stream.Collectors;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;

@Service
@RequiredArgsConstructor
public class FieldWorkService {
    private static final ZoneId ZONE = ZoneId.of("Asia/Ho_Chi_Minh");
    private final FieldWorkDayRepository days;
    private final UserRepository users;
    private final NotificationService notifications;

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
        day.setStatus("PENDING");
        day.setReviewedBy(null);
        day.setReviewedAt(null);
        FieldWorkDay saved = days.saveAndFlush(day);
        notifications.sendToRoles(List.of(
                UserRole.ADMIN,
                UserRole.SUPER_ADMIN),
                NotificationType.FIELD_WORK_PENDING,
                "Yêu cầu đi công trình chờ duyệt", notificationBody(day),
                "FIELD_WORK", saved.getId() == null ? null : saved.getId().toString(), true);
        return toResponse(saved);
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
        return days.findByEmployeeIdAndWorkDateBetweenAndIsDeletedFalseOrderByWorkDateDesc(employeeId, start, end)
                .stream().map(FieldWorkService::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<FieldWorkDayResponse> pending() {
        List<FieldWorkDay> pending = days.findTop100ByStatusAndIsDeletedFalseOrderByCreatedAtAsc("PENDING");
        Map<UUID, String> names = users.findAllById(pending.stream().map(FieldWorkDay::getEmployeeId).distinct().toList())
                .stream().collect(Collectors.toMap(UserEntity::getId,
                        user -> user.getFullName() == null ? user.getId().toString() : user.getFullName()));
        return pending.stream().map(day -> {
            String name = names.getOrDefault(day.getEmployeeId(), day.getEmployeeId().toString());
            return new FieldWorkDayResponse(day.getId(), day.getEmployeeId(), day.getWorkDate(), day.getNote(),
                    day.getCreatedAt(), day.getUpdatedAt(), day.getStatus(), day.getReviewedBy(), day.getReviewedAt(), name, day.getVersion());
        }).toList();
    }

    @Transactional
    public FieldWorkDayResponse review(UUID id, UUID reviewerId, boolean approve, Long version) {
        FieldWorkDay initial = days.findById(id).orElseThrow(() -> new BusinessException("Không tìm thấy yêu cầu"));
        requireEmployeeForUpdate(initial.getEmployeeId());
        FieldWorkDay day = days.findById(id).orElseThrow(() -> new BusinessException("Không tìm thấy yêu cầu"));
        if (Boolean.TRUE.equals(day.getIsDeleted()) || !"PENDING".equals(day.getStatus())) {
            throw new BusinessException("Yêu cầu không còn chờ duyệt");
        }
        if (!Objects.equals(version, day.getVersion())) {
            throw new BusinessException("Yêu cầu đã thay đổi, vui lòng tải lại trước khi duyệt");
        }
        if (reviewerId.equals(day.getEmployeeId())) {
            throw new BusinessException("Không thể tự duyệt yêu cầu của mình");
        }
        day.setStatus(approve ? "APPROVED" : "REJECTED");
        day.setReviewedBy(reviewerId);
        day.setReviewedAt(Instant.now());
        day.setUpdatedBy(reviewerId);
        FieldWorkDay saved = days.saveAndFlush(day);
        notifications.sendToUser(day.getEmployeeId(),
                NotificationType.FIELD_WORK_REVIEWED,
                approve ? "Đi công trình đã được chấp nhận" : "Yêu cầu đi công trình bị từ chối",
                notificationBody(day), "FIELD_WORK", id.toString(), true);
        return toResponse(saved);
    }

    private static String notificationBody(FieldWorkDay day) {
        String note = day.getNote();
        return day.getWorkDate() + " — " + (note.length() > 200 ? note.substring(0, 200) + "…" : note);
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
                day.getNote(), day.getCreatedAt(), day.getUpdatedAt(), day.getStatus(), day.getReviewedBy(), day.getReviewedAt(), null, day.getVersion());
    }

    public static String displayNote(FieldWorkDay day) {
        return "Đi công trình — " + day.getNote();
    }
}

