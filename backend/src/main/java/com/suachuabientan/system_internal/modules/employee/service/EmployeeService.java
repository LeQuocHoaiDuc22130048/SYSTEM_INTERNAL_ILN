package com.suachuabientan.system_internal.modules.employee.service;

import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.service.RbacService;
import com.suachuabientan.system_internal.modules.auth.enums.UserStatus;
import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.attendance.entity.AttendanceRecord;
import com.suachuabientan.system_internal.modules.attendance.enums.AttendanceType;
import com.suachuabientan.system_internal.modules.attendance.repository.AttendanceRecordRepository;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.employee.dto.request.UpdateEmployeeRequest;
import com.suachuabientan.system_internal.modules.employee.dto.request.EnrollFaceRequest;
import com.suachuabientan.system_internal.modules.employee.dto.response.EmployeeDetailResponse;
import com.suachuabientan.system_internal.modules.employee.dto.response.EmployeeEmbeddingDeltaResponse;
import com.suachuabientan.system_internal.modules.employee.dto.response.EmployeeEmbeddingMetadataResponse;
import com.suachuabientan.system_internal.modules.employee.dto.response.EmployeeFaceEmbeddingResponse;
import com.suachuabientan.system_internal.modules.employee.dto.response.FaceEmbeddingCalibrationResponse;
import com.suachuabientan.system_internal.modules.employee.dto.response.EmployeeScheduleResponse;
import com.suachuabientan.system_internal.modules.attendance.service.FaceRecognitionService;
import com.suachuabientan.system_internal.modules.repair.repository.RepairOrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class EmployeeService implements InitializingBean {

    private final UserRepository userRepository;
    private final AttendanceRecordRepository attendanceRepository;
    private final RepairOrderRepository repairOrderRepository;
    private final FaceRecognitionService faceRecognitionService;
    private final RbacService rbacService;
    private static final ZoneId ZONE_VN = ZoneId.of("Asia/Ho_Chi_Minh");
    private static final String FACE_MODEL_NAME = "face-embedding";

    @Value("${app.attendance.face.match-threshold:${ATTENDANCE_FACE_MATCH_THRESHOLD:#{null}}}")
    private Double faceMatchThreshold;

    @Value("${app.attendance.face.calibration.far:${ATTENDANCE_FACE_CALIBRATION_FAR:#{null}}}")
    private Double faceCalibrationFar;

    @Value("${app.attendance.face.calibration.frr:${ATTENDANCE_FACE_CALIBRATION_FRR:#{null}}}")
    private Double faceCalibrationFrr;

    @Value("${app.attendance.face.calibration.dataset-version:${ATTENDANCE_FACE_CALIBRATION_DATASET_VERSION:}}")
    private String faceCalibrationDatasetVersion;

    @Value("${app.attendance.face.calibration.calibrated-at:${ATTENDANCE_FACE_CALIBRATED_AT:}}")
    private String faceCalibratedAt;

    @Value("${app.attendance.face.calibration.report-path:${ATTENDANCE_FACE_CALIBRATION_REPORT_PATH:}}")
    private String faceCalibrationReportPath;

    @Value("${app.face-recognition.skip-duplicate-check:false}")
    private boolean skipFaceDuplicateCheck;

    @Override
    public void afterPropertiesSet() {
        if (faceMatchThreshold == null
                || faceMatchThreshold < 0.0
                || faceMatchThreshold > 1.0) {
            throw new IllegalStateException(
                    "ATTENDANCE_FACE_MATCH_THRESHOLD must be calibrated from real company data and stay in 0.0..1.0");
        }
        if (faceCalibrationFar == null || faceCalibrationFrr == null) {
            throw new IllegalStateException(
                    "Face model calibration FAR/FRR are required. Run calibration on real employee images and set "
                            + "ATTENDANCE_FACE_CALIBRATION_FAR and ATTENDANCE_FACE_CALIBRATION_FRR.");
        }
        if (!StringUtils.hasText(faceCalibrationDatasetVersion)
                || !StringUtils.hasText(faceCalibratedAt)
                || !StringUtils.hasText(faceCalibrationReportPath)) {
            throw new IllegalStateException(
                    "Face model calibration metadata is required: dataset-version, calibrated-at, and report-path.");
        }
        try {
            Instant.parse(faceCalibratedAt);
        } catch (Exception error) {
            throw new IllegalStateException("ATTENDANCE_FACE_CALIBRATED_AT must be ISO-8601 Instant", error);
        }
    }

    @Transactional
    public Page<EmployeeDetailResponse> searchEmployees(String keyword, Pageable pageable) {
        return userRepository.searchUsers(keyword, pageable).map(this::toDetailResponse);
    }

    @Transactional
    public EmployeeDetailResponse getById(UUID id) {
        return toDetailResponse(findUserById(id));
    }

    @Transactional(readOnly = true)
    public List<EmployeeFaceEmbeddingResponse> getFaceEmbeddings() {
        return activeFaceUsers().stream().map(this::toFaceEmbeddingResponse).toList();
    }

    @Transactional(readOnly = true)
    public EmployeeEmbeddingMetadataResponse getFaceEmbeddingMetadata() {
        List<UserEntity> users = activeFaceUsers();
        return new EmployeeEmbeddingMetadataResponse(
                FACE_MODEL_NAME,
                faceEmbeddingVersion(users),
                faceEmbeddingChecksum(users),
                faceMatchThreshold,
                faceCalibration(),
                users.size());
    }

    @Transactional(readOnly = true)
    public EmployeeEmbeddingDeltaResponse getFaceEmbeddingChanges(Instant since) {
        Instant effectiveSince = since != null ? since : Instant.EPOCH;
        List<UserEntity> activeUsers = activeFaceUsers();
        List<UserEntity> changedUsers = userRepository.findByUpdatedAtAfter(effectiveSince);

        List<EmployeeFaceEmbeddingResponse> changed = changedUsers.stream()
                .filter(this::isActiveFaceUser)
                .map(this::toFaceEmbeddingResponse)
                .toList();
        List<UUID> removedEmployeeIds = changedUsers.stream()
                .filter(user -> !isActiveFaceUser(user))
                .map(UserEntity::getId)
                .distinct()
                .toList();

        return new EmployeeEmbeddingDeltaResponse(
                FACE_MODEL_NAME,
                faceEmbeddingVersion(activeUsers),
                faceEmbeddingChecksum(activeUsers),
                faceMatchThreshold,
                faceCalibration(),
                changed,
                removedEmployeeIds);
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
        if (StringUtils.hasText(request.role()) && isManager) {
            try {
                UserRole newRole = UserRole.valueOf(request.role().toUpperCase());
                user.setRole(newRole);
                rbacService.updateRole(user.getId(), newRole);
            } catch (IllegalArgumentException e) {
                throw new BusinessException("Vai trò không hợp lệ: " + request.role(), 400);
            }
        }

        log.info("Cập nhật nhân viên: targetId={}, by={}", targetId, requesterId);
        return toDetailResponse(userRepository.save(user));
    }

    // ── Enroll khuôn mặt ─────────────────────────────────────

    /**
     * Đăng ký khuôn mặt cho nhân viên — chỉ Admin thực hiện.
     * Anh crop duoc chuyen cho dich vu FaceNet/OpenCV de tao embedding.
     */
    @Transactional
    public EmployeeDetailResponse enrollFace(UUID employeeId, EnrollFaceRequest request, UUID adminId) {
        List<FaceRecognitionService.FaceImageSample> samples = request.samples() == null
                ? List.of()
                : request.samples().stream()
                .map(sample -> new FaceRecognitionService.FaceImageSample(
                        sample.faceImageBase64(),
                        sample.imageContentType()))
                .toList();
        if (samples.isEmpty()) {
            return enrollFace(employeeId, request.faceImageBase64(), request.imageContentType(), adminId);
        }

        UserEntity user = findUserById(employeeId);
        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new BusinessException("Chá»‰ cÃ³ thá»ƒ Ä‘Äƒng kÃ½ khuÃ´n máº·t cho nhÃ¢n viÃªn Ä‘ang hoáº¡t Ä‘á»™ng");
        }

        ensureEmployeeHasNoFace(user);
        List<Double> averagedEncoding = faceRecognitionService.encodeAverage(samples);
        ensureFaceNotAlreadyEnrolled(user, averagedEncoding);
        user.setFaceEncoding(faceRecognitionService.serializeEncoding(averagedEncoding));
        user.setFaceEnrolled(true);
        user.setFaceVerifiedBy(adminId);

        log.info("ÄÄƒng kÃ½ khuÃ´n máº·t nhiá»u máº«u: employeeId={}, samples={}, by={}",
                employeeId, samples.size(), adminId);
        return toDetailResponse(userRepository.save(user));
    }

    @Transactional
    public EmployeeDetailResponse enrollFace(UUID employeeId, String faceImageBase64,
                                             String imageContentType,
                                             UUID adminId) {
        UserEntity user = findUserById(employeeId);

        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new BusinessException("Chỉ có thể đăng ký khuôn mặt cho nhân viên đang hoạt động");
        }

        ensureEmployeeHasNoFace(user);
        List<Double> encoding = faceRecognitionService.encode(faceImageBase64, imageContentType);
        ensureFaceNotAlreadyEnrolled(user, encoding);
        user.setFaceEncoding(faceRecognitionService.serializeEncoding(encoding));
        user.setFaceEnrolled(true);
        user.setFaceVerifiedBy(adminId);

        log.info("Đăng ký khuôn mặt: employeeId={}, by={}", employeeId, adminId);
        return toDetailResponse(userRepository.save(user));
    }

    // ── Suspend / Activate ────────────────────────────────────

    @Transactional
    public EmployeeDetailResponse deleteFace(UUID employeeId, UUID adminId) {
        UserEntity user = findUserById(employeeId);
        if (!Boolean.TRUE.equals(user.getFaceEnrolled()) && !StringUtils.hasText(user.getFaceEncoding())) {
            throw new BusinessException("Nhan vien nay chua co khuon mat dang ky", 400);
        }

        user.setFaceEncoding(null);
        user.setFaceEnrolled(false);
        user.setFaceVerifiedBy(null);
        log.info("Xoa khuon mat da dang ky: employeeId={}, by={}", employeeId, adminId);
        return toDetailResponse(userRepository.save(user));
    }

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

    private void ensureFaceNotAlreadyEnrolled(UserEntity targetUser, List<Double> candidateEncoding) {
        if (skipFaceDuplicateCheck) {
            log.warn(
                    "app.face-recognition.skip-duplicate-check=true is ignored for employeeId={} because duplicate face enrollment is not allowed",
                    targetUser.getId());
        }
        activeFaceUsers().stream()
                .filter(user -> !user.getId().equals(targetUser.getId()))
                .map(user -> new FaceDuplicateCandidate(
                        user,
                        faceRecognitionService.cosineSimilarity(user.getFaceEncoding(), candidateEncoding)))
                .filter(candidate -> candidate.score() >= faceMatchThreshold)
                .max(Comparator.comparingDouble(FaceDuplicateCandidate::score))
                .ifPresent(candidate -> {
                    throw new BusinessException(
                            "Khuon mat nay da duoc dang ky cho nhan vien: "
                                    + candidate.user().getEmployeeCode()
                                    + " - "
                                    + candidate.user().getFullName(),
                            409);
                });
    }

    private void ensureEmployeeHasNoFace(UserEntity user) {
        if (Boolean.TRUE.equals(user.getFaceEnrolled()) || StringUtils.hasText(user.getFaceEncoding())) {
            throw new BusinessException(
                    "Nhan vien "
                            + nullToEmpty(user.getEmployeeCode())
                            + " - "
                            + nullToEmpty(user.getFullName())
                            + " da co khuon mat dang ky. Khong duoc dang ky lai de tranh nham khuon mat",
                    409);
        }
    }

    private List<UserEntity> activeFaceUsers() {
        return userRepository
                .findByStatusAndFaceEnrolledTrueAndFaceEncodingIsNotNullAndIsDeletedFalse(UserStatus.ACTIVE)
                .stream()
                .sorted(Comparator.comparing(UserEntity::getId))
                .toList();
    }

    private boolean isActiveFaceUser(UserEntity user) {
        return user.isActive()
                && Boolean.TRUE.equals(user.getFaceEnrolled())
                && StringUtils.hasText(user.getFaceEncoding());
    }

    private EmployeeFaceEmbeddingResponse toFaceEmbeddingResponse(UserEntity user) {
        return new EmployeeFaceEmbeddingResponse(
                user.getId(),
                user.getEmployeeCode(),
                user.getFullName(),
                FACE_MODEL_NAME,
                user.getFaceEncoding(),
                user.getUpdatedAt());
    }

    private FaceEmbeddingCalibrationResponse faceCalibration() {
        return new FaceEmbeddingCalibrationResponse(
                faceMatchThreshold,
                faceCalibrationFar,
                faceCalibrationFrr,
                faceCalibrationDatasetVersion,
                Instant.parse(faceCalibratedAt),
                faceCalibrationReportPath);
    }

    private Instant faceEmbeddingVersion(List<UserEntity> users) {
        return users.stream()
                .map(UserEntity::getUpdatedAt)
                .filter(updatedAt -> updatedAt != null)
                .max(Instant::compareTo)
                .orElse(Instant.EPOCH);
    }

    private String faceEmbeddingChecksum(List<UserEntity> users) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            for (UserEntity user : users) {
                digest.update(user.getId().toString().getBytes(StandardCharsets.UTF_8));
                digest.update((byte) ':');
                digest.update(nullToEmpty(user.getUpdatedAt()).getBytes(StandardCharsets.UTF_8));
                digest.update((byte) ':');
                digest.update(nullToEmpty(user.getFaceEncoding()).getBytes(StandardCharsets.UTF_8));
                digest.update((byte) '\n');
            }
            return toHex(digest.digest());
        } catch (NoSuchAlgorithmException error) {
            throw new IllegalStateException("SHA-256 is not available", error);
        }
    }

    private String nullToEmpty(Object value) {
        return value == null ? "" : value.toString();
    }

    private String toHex(byte[] bytes) {
        StringBuilder builder = new StringBuilder(bytes.length * 2);
        for (byte value : bytes) {
            builder.append(String.format("%02x", value));
        }
        return builder.toString();
    }

    private record FaceDuplicateCandidate(UserEntity user, double score) {
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
