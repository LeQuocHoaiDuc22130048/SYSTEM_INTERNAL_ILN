package com.suachuabientan.system_internal.modules.employee.service;

import com.suachuabientan.system_internal.common.enums.UserRole;
import com.suachuabientan.system_internal.common.enums.UserStatus;
import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.attendance.entity.AttendanceRecord;
import com.suachuabientan.system_internal.modules.attendance.enums.AttendanceType;
import com.suachuabientan.system_internal.modules.attendance.repository.AttendanceRecordRepository;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.employee.dto.request.UpdateEmployeeRequest;
import com.suachuabientan.system_internal.modules.employee.dto.response.EmployeeDetailResponse;
import com.suachuabientan.system_internal.modules.employee.dto.response.EmployeeScheduleResponse;
import com.suachuabientan.system_internal.modules.repository.RepairOrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class EmployeeService {

    private final UserRepository userRepository;
    private final AttendanceRecordRepository attendanceRepository;
    private final RepairOrderRepository repairOrderRepository;
    private static final ZoneId ZONE_VN = ZoneId.of("Asia/Ho_Chi_Minh");

    @Transactional
    public Page<EmployeeDetailResponse> searchEmployees(String keyword, Pageable pageable) {
        return userRepository.searchUsers(keyword, pageable).map(this::toDetailResponse);
    }

    @Transactional
    public EmployeeDetailResponse getById(UUID id) {
        return toDetailResponse(findUserById(id));
    }
// ── Cập nhật thông tin ────────────────────────────────────

    /**
     * Cập nhật thông tin cá nhân.
     * Nhân viên chỉ được sửa thông tin của mình.
     * Admin/Manager được sửa thông tin của bất kỳ ai.
     */
    @Transactional
    public EmployeeDetailResponse update(UUID targetId, UpdateEmployeeRequest request,
                                         UUID requesterId, boolean isManager) {
        if (!targetId.equals(requesterId) && !isManager) {
            throw new BusinessException("Bạn không có quyền cập nhật thông tin nhân viên khác", 403);
        }

        UserEntity user = findUserById(targetId);

        if (StringUtils.hasText(request.fullName())) user.setFullName(request.fullName());
        if (StringUtils.hasText(request.department())) user.setDepartment(request.department());
        if (StringUtils.hasText(request.phone())) user.setPhone(request.phone());
        if (StringUtils.hasText(request.address())) user.setAddress(request.address());
        if (StringUtils.hasText(request.avatarUrl())) user.setAvatarUrl(request.avatarUrl());

        log.info("Cập nhật nhân viên: targetId={}, by={}", targetId, requesterId);
        return toDetailResponse(userRepository.save(user));
    }

    // ── Enroll khuôn mặt ─────────────────────────────────────

    /**
     * Đăng ký khuôn mặt cho nhân viên — chỉ Admin thực hiện.
     * Face encoding (JSON vector) đã được xử lý bởi Python service.
     */
    @Transactional
    public EmployeeDetailResponse enrollFace(UUID employeeId, String faceEncoding,
                                             UUID adminId) {
        UserEntity user = findUserById(employeeId);

        if (!StringUtils.hasText(faceEncoding)) {
            throw new BusinessException("Face encoding không được để trống");
        }

        user.setFaceEncoding(faceEncoding);
        user.setFaceEnrolled(true);
        user.setFaceVerifiedBy(adminId);

        log.info("Đăng ký khuôn mặt: employeeId={}, by={}", employeeId, adminId);
        return toDetailResponse(userRepository.save(user));
    }

    // ── Suspend / Activate ────────────────────────────────────

    @Transactional
    public EmployeeDetailResponse suspend(UUID targetId, UUID requesterId) {
        if (targetId.equals(requesterId)) {
            throw new BusinessException("Không thể tự khoá tài khoản của mình");
        }
        UserEntity user = findUserById(targetId);
        if (user.getRole() == UserRole.SUPER_ADMIN) {
            throw new BusinessException("Không thể khoá tài khoản SUPER_ADMIN");
        }
        user.suspend();
        log.info("Khoá tài khoản: userId={}, by={}", targetId, requesterId);
        return toDetailResponse(userRepository.save(user));
    }

    @Transactional
    public EmployeeDetailResponse activate(UUID targetId, UUID requesterId) {
        UserEntity user = findUserById(targetId);
        if (user.getStatus() != UserStatus.SUSPENDED) {
            throw new BusinessException("Tài khoản không ở trạng thái bị khoá");
        }
        user.setStatus(UserStatus.ACTIVE);
        log.info("Mở khoá tài khoản: userId={}, by={}", targetId, requesterId);
        return toDetailResponse(userRepository.save(user));
    }

    // ── Lịch trình nhân viên ──────────────────────────────────

    /**
     * Lịch trình hoạt động theo khoảng ngày.
     * Tổng hợp repair orders + attendance trong cùng một ngày.
     */
    @Transactional(readOnly = true)
    public List<EmployeeScheduleResponse> getSchedule(UUID employeeId, LocalDate from, LocalDate to) {
        findUserById(employeeId); // Validate tồn tại

        List<EmployeeScheduleResponse> result = new ArrayList<>();

        // Duyệt từng ngày trong khoảng
        for (LocalDate date = from; !date.isAfter(to); date = date.plusDays(1)) {
            Instant dayStart = date.atStartOfDay(ZONE_VN).toInstant();
            Instant dayEnd = date.plusDays(1).atStartOfDay(ZONE_VN).toInstant();

            // Repair activities trong ngày
            List<EmployeeScheduleResponse.RepairActivity> activities =
                    buildRepairActivities(employeeId, dayStart, dayEnd);

            // Chấm công trong ngày
            EmployeeScheduleResponse.AttendanceSummary attendance =
                    buildAttendanceSummary(employeeId, dayStart, dayEnd);

            // Chỉ thêm vào kết quả nếu có hoạt động
            if (!activities.isEmpty() || attendance != null) {
                result.add(new EmployeeScheduleResponse(date, activities, attendance));
            }
        }

        return result;
    }

    private UserEntity findUserById(UUID id) {
        return userRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> new ResourceNotFoundException(
                        STR."Không tìm thấy nhân viên: \{id}"));
    }

    private List<EmployeeScheduleResponse.RepairActivity> buildRepairActivities(
            UUID employeeId, Instant dayStart, Instant dayEnd) {
        return repairOrderRepository
                .findActiveByAssignedTo(employeeId)
                .stream()
                .filter(o -> {
                    // Lọc đơn liên quan đến ngày này
                    Instant ref = o.getStartedAt() != null ? o.getStartedAt() : o.getReceivedAt();
                    return ref != null && !ref.isBefore(dayStart) && ref.isBefore(dayEnd);
                })
                .map(o -> new EmployeeScheduleResponse.RepairActivity(
                        o.getId(), o.getOrderCode(), o.getDeviceName(),
                        o.getCustomerName(), o.getStatus().name(),
                        o.getReceivedAt(), o.getCompletedAt()))
                .toList();
    }

    private EmployeeScheduleResponse.AttendanceSummary buildAttendanceSummary(
            UUID employeeId, Instant dayStart, Instant dayEnd) {
        var records = attendanceRepository.findTodayRecords(employeeId, dayStart, dayEnd);
        if (records.isEmpty()) return null;

        var firstIn = records.stream()
                .filter(r -> r.getType() == AttendanceType.IN && Boolean.TRUE.equals(r.getIsValid()))
                .map(AttendanceRecord::getCheckTime)
                .min(Instant::compareTo).orElse(null);
        var lastOut = records.stream()
                .filter(r -> r.getType() == AttendanceType.OUT && Boolean.TRUE.equals(r.getIsValid()))
                .map(AttendanceRecord::getCheckTime)
                .max(Instant::compareTo).orElse(null);

        Long totalMinutes = (firstIn != null && lastOut != null)
                ? Duration.between(firstIn, lastOut).toMinutes() : null;

        return new EmployeeScheduleResponse.AttendanceSummary(firstIn, lastOut, totalMinutes);
    }

    private EmployeeDetailResponse toDetailResponse(UserEntity user) {
        return new EmployeeDetailResponse(
                user.getId(),
                user.getUsername(),
                user.getFullName(),
                user.getEmployeeCode(),
                user.getDepartment(),
                user.getPhone(),
                user.getAddress(),
                user.getRole().name(),
                user.getStatus().name(),
                user.getAvatarUrl(),
                user.getFaceEnrolled(),
                user.getApprovedAt(),
                user.getCreatedAt()
        );
    }
}
