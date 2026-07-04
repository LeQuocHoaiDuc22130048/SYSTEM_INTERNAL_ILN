package com.suachuabientan.system_internal.modules.attendance.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.attendance.dto.request.CheckinRequest;
import com.suachuabientan.system_internal.modules.attendance.dto.request.AttendanceSyncItemRequest;
import com.suachuabientan.system_internal.modules.attendance.dto.request.AttendanceSyncRequest;
import com.suachuabientan.system_internal.modules.attendance.dto.request.CreateScheduleRequest;
import com.suachuabientan.system_internal.modules.attendance.dto.request.FaceCheckinRequest;
import com.suachuabientan.system_internal.modules.attendance.dto.request.ManualCheckinRequest;
import com.suachuabientan.system_internal.modules.attendance.dto.request.UpdateAttendanceRecordRequest;
import com.suachuabientan.system_internal.modules.attendance.dto.response.AttendanceResponse;
import com.suachuabientan.system_internal.modules.attendance.dto.response.AttendanceSyncItemResponse;
import com.suachuabientan.system_internal.modules.attendance.dto.response.AttendanceSyncResponse;
import com.suachuabientan.system_internal.modules.attendance.dto.response.DailyAttendanceResponse;
import com.suachuabientan.system_internal.modules.attendance.dto.response.WorkScheduleResponse;
import com.suachuabientan.system_internal.modules.attendance.entity.AttendanceRecord;
import com.suachuabientan.system_internal.modules.attendance.entity.WorkSchedule;
import com.suachuabientan.system_internal.modules.attendance.enums.AttendanceType;
import com.suachuabientan.system_internal.modules.attendance.repository.AttendanceRecordRepository;
import com.suachuabientan.system_internal.modules.attendance.repository.WorkScheduleRepository;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.enums.UserStatus;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.Comparator;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class AttendanceService {
    private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Ho_Chi_Minh");
    private static final LocalTime DEFAULT_SHIFT_START = LocalTime.of(8, 0);
    private static final LocalTime DEFAULT_SHIFT_END = LocalTime.of(17, 0);
    private static final Duration LATE_GRACE = Duration.ofMinutes(15);
    private static final Duration OFFLINE_DEDUP_WINDOW = Duration.ofMinutes(2);

    private final AttendanceRecordRepository attendanceRecordRepository;
    private final WorkScheduleRepository workScheduleRepository;
    private final UserRepository userRepository;
    private final FaceRecognitionService faceRecognitionService;
    private final NotificationService notificationService;
    private final FaceRecognitionMonitoringService faceRecognitionMonitoringService;

    @Value("${app.attendance.face.match-threshold}")
    private double faceMatchThreshold;

    @Value("${app.attendance.face.ambiguous-margin:${ATTENDANCE_FACE_AMBIGUOUS_MARGIN:0.03}}")
    private double faceAmbiguousMargin;

    @Transactional
    public AttendanceResponse check(UUID employeeId, CheckinRequest request) {
        UserEntity employee = findUser(employeeId);
        return recordAttendance(employee, request.deviceId(), request.note(), null);
    }

    @Transactional
    public AttendanceResponse faceCheck(UUID employeeId, FaceCheckinRequest request) {
        long startedAt = System.nanoTime();
        UserEntity employee = findUser(employeeId);
        if (!Boolean.TRUE.equals(employee.getFaceEnrolled()) || employee.getFaceEncoding() == null) {
            throw new BusinessException("Nhân viên chưa đăng ký khuôn mặt", 400);
        }

        FaceRecognitionService.FaceVerificationResult verification = faceRecognitionService.verify(
                employee.getFaceEncoding(),
                request.faceImageBase64(),
                request.imageContentType());
        faceRecognitionMonitoringService.recordServerOnlineAttempt(
                employee.getId(),
                employee.getFullName(),
                employeeId,
                request.deviceId(),
                "face-embedding",
                verification.matched(),
                verification.confidence(),
                faceMatchThreshold);
        if (!verification.matched()) {
            logAttendanceDecision(
                    "attendance.face_check",
                    employee.getId(),
                    request.deviceId(),
                    verification.confidence(),
                    elapsedMs(startedAt),
                    "REJECTED",
                    null,
                    null);
            throw new BusinessException(lowConfidenceMessage(verification.confidence()), 403);
        }

        AttendanceResponse response = recordAttendance(
                employee,
                request.deviceId(),
                "Chấm công bằng khuôn mặt từ ứng dụng",
                verification.confidence());
        logAttendanceDecision(
                "attendance.face_check",
                employee.getId(),
                request.deviceId(),
                verification.confidence(),
                elapsedMs(startedAt),
                "MATCHED",
                response.type(),
                response.id());
        return response;
    }

    @Transactional
    public AttendanceResponse faceIdentify(UUID operatorId, FaceCheckinRequest request) {
        long startedAt = System.nanoTime();
        List<Double> candidateEncoding = faceRecognitionService.encode(
                request.faceImageBase64(),
                request.imageContentType());
        List<UserEntity> enrolledEmployees = userRepository
                .findByStatusAndFaceEnrolledTrueAndFaceEncodingIsNotNullAndIsDeletedFalse(UserStatus.ACTIVE);
        if (enrolledEmployees.isEmpty()) {
            throw new BusinessException("Chua co nhan vien nao dang ky khuon mat. Vui long dang ky khuon mat truoc khi cham cong.", 400);
        }

        FaceCandidate best = null;
        double secondBestScore = -1.0;
        for (UserEntity employee : enrolledEmployees) {
            double score = faceRecognitionService.cosineSimilarity(employee.getFaceEncoding(), candidateEncoding);
            if (best == null || score > best.score()) {
                secondBestScore = best == null ? -1.0 : best.score();
                best = new FaceCandidate(employee, score);
            } else if (score > secondBestScore) {
                secondBestScore = score;
            }
        }
        if (best == null) {
            throw new BusinessException("Khong tim thay ung vien khuon mat", 403);
        }

        boolean scorePassed = best.score() >= faceMatchThreshold;
        boolean ambiguous = scorePassed
                && secondBestScore >= 0.0
                && best.score() - secondBestScore < faceAmbiguousMargin;
        boolean matched = scorePassed && !ambiguous;
        faceRecognitionMonitoringService.recordServerOnlineAttempt(
                best.employee().getId(),
                best.employee().getFullName(),
                operatorId,
                request.deviceId(),
                "face-embedding",
                matched,
                best.score(),
                faceMatchThreshold);
        if (!matched) {
            String rejectionResult = ambiguous ? "REJECTED_AMBIGUOUS" : "REJECTED_LOW_CONFIDENCE";
            logAttendanceDecision(
                    "attendance.face_identify",
                    best.employee().getId(),
                    request.deviceId(),
                    best.score(),
                    elapsedMs(startedAt),
                    rejectionResult,
                    null,
                    null);
            throw new BusinessException(
                    ambiguous
                            ? ambiguousFaceMessage(best.score(), secondBestScore)
                            : lowConfidenceMessage(best.score()),
                    403);
        }

        AttendanceResponse response = recordAttendance(
                best.employee(),
                request.deviceId(),
                "Chấm công bằng nhận diện khuôn mặt từ tablet",
                best.score());
        logAttendanceDecision(
                "attendance.face_identify",
                best.employee().getId(),
                request.deviceId(),
                best.score(),
                elapsedMs(startedAt),
                "MATCHED",
                response.type(),
                response.id());
        return response;
    }

    private AttendanceResponse recordAttendance(
            UserEntity employee,
            String deviceId,
            String note,
            Double confidenceScore) {
        UUID employeeId = employee.getId();
        LocalDate today = LocalDate.now(BUSINESS_ZONE);
        Instant dayStart = startOfDay(today);
        Instant dayEnd = startOfDay(today.plusDays(1));

        List<AttendanceRecord> todayRecords = attendanceRecordRepository
                .findTodayRecords(employeeId, dayStart, dayEnd)
                .stream()
                .filter(record -> Boolean.TRUE.equals(record.getIsValid()))
                .sorted(Comparator.comparing(AttendanceRecord::getCheckTime).reversed())
                .toList();

        AttendanceType nextType = todayRecords.isEmpty()
                ? AttendanceType.IN
                : todayRecords.getFirst().getType() == AttendanceType.IN ? AttendanceType.OUT : AttendanceType.IN;

        AttendanceRecord record = AttendanceRecord.builder()
                .employeeId(employeeId)
                .type(nextType)
                .checkTime(Instant.now())
                .deviceId(deviceId)
                .note(note)
                .confidenceScore(confidenceScore)
                .isValid(true)
                .build();

        AttendanceRecord saved = attendanceRecordRepository.save(record);
        log.info("Internal attendance recorded: employeeId={}, type={}, recordId={}",
                employeeId, nextType, saved.getId());
        return toAttendanceResponse(saved, employee);
    }

    @Transactional
    public AttendanceResponse manualCheck(ManualCheckinRequest request, UUID createdByUserId) {
        UserEntity employee = findUser(request.employeeId());
        AttendanceRecord record = AttendanceRecord.builder()
                .employeeId(request.employeeId())
                .type(request.type())
                .checkTime(request.checkTime())
                .note(request.note())
                .isValid(true)
                .build();

        AttendanceRecord saved = attendanceRecordRepository.save(record);
        log.info("Manual attendance recorded: employeeId={}, type={}, by={}, recordId={}",
                request.employeeId(), request.type(), createdByUserId, saved.getId());
        return toAttendanceResponse(saved, employee);
    }

    @Transactional
    public AttendanceSyncResponse syncOfflineLogs(AttendanceSyncRequest request, UUID syncedByUserId) {
        List<AttendanceSyncItemResponse> results = new ArrayList<>();
        int synced = 0;
        int skipped = 0;
        int failed = 0;

        for (AttendanceSyncItemRequest item : request.logs()) {
            long itemStartedAt = System.nanoTime();
            try {
                var existingByDeviceLog = attendanceRecordRepository
                        .findByDeviceLogIdAndIsDeletedFalse(item.localLogId());
                if (existingByDeviceLog.isPresent()) {
                    AttendanceRecord existing = existingByDeviceLog.get();
                    results.add(new AttendanceSyncItemResponse(
                            item.localLogId(),
                            "SKIPPED",
                            existing.getId(),
                            "Duplicate device log"));
                    logAttendanceDecision(
                            "attendance.offline_sync",
                            item.employeeId(),
                            item.deviceId(),
                            item.confidenceScore(),
                            elapsedMs(itemStartedAt),
                            "SKIPPED_DEVICE_LOG_DUPLICATE",
                            item.type().name(),
                            existing.getId());
                    skipped++;
                    continue;
                }

                UserEntity employee = findUserForOfflineSync(item);
                Instant mobileCheckTime = mobileCheckTime(item);
                Instant dedupFrom = mobileCheckTime.minus(OFFLINE_DEDUP_WINDOW);
                Instant dedupTo = mobileCheckTime.plus(OFFLINE_DEDUP_WINDOW);
                List<AttendanceRecord> dedupCandidates = attendanceRecordRepository.findDedupCandidates(
                        item.employeeId(),
                        item.type().name(),
                        dedupFrom,
                        dedupTo);
                if (!dedupCandidates.isEmpty()) {
                    AttendanceRecord duplicate = dedupCandidates.getFirst();
                    results.add(new AttendanceSyncItemResponse(
                            item.localLogId(),
                            "SKIPPED",
                            duplicate.getId(),
                            "Duplicate employee timestamp within 2 minutes"));
                    logAttendanceDecision(
                            "attendance.offline_sync",
                            item.employeeId(),
                            item.deviceId(),
                            item.confidenceScore(),
                            elapsedMs(itemStartedAt),
                            "SKIPPED_NEARBY_DUPLICATE",
                            item.type().name(),
                            duplicate.getId());
                    skipped++;
                    continue;
                }

                double serverConfidence = verifyOfflineFaceEmbedding(employee, item, syncedByUserId);
                Instant serverCheckTime = Instant.now();
                AttendanceRecord record = AttendanceRecord.builder()
                        .employeeId(item.employeeId())
                        .type(item.type())
                        .checkTime(serverCheckTime)
                        .mobileCheckTime(mobileCheckTime)
                        .confidenceScore(serverConfidence)
                        .deviceId(item.deviceId())
                        .deviceLogId(item.localLogId())
                        .faceImagePath(null)
                        .note(item.note())
                        .isValid(true)
                        .build();

                AttendanceRecord saved = attendanceRecordRepository.save(record);
                logAttendanceDecision(
                        "attendance.offline_sync",
                        employee.getId(),
                        item.deviceId(),
                        serverConfidence,
                        elapsedMs(itemStartedAt),
                        "SYNCED",
                        item.type().name(),
                        saved.getId());
                results.add(new AttendanceSyncItemResponse(
                        item.localLogId(),
                        "SYNCED",
                        saved.getId(),
                        null));
                synced++;
            } catch (Exception error) {
                results.add(new AttendanceSyncItemResponse(
                        item.localLogId(),
                        "FAILED",
                        null,
                        error.getMessage()));
                logAttendanceDecision(
                        "attendance.offline_sync",
                        item.employeeId(),
                        item.deviceId(),
                        item.confidenceScore(),
                        elapsedMs(itemStartedAt),
                        "FAILED",
                        item.type() == null ? null : item.type().name(),
                        null);
                failed++;
            }
        }

        return new AttendanceSyncResponse(request.logs().size(), synced, skipped, failed, results);
    }

    private UserEntity findUserForOfflineSync(AttendanceSyncItemRequest item) {
        UserEntity employee = userRepository.findById(item.employeeId())
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay nhan vien: " + item.employeeId()));
        if (Boolean.TRUE.equals(employee.getIsDeleted())) {
            notifyDeletedEmployeeSyncFailure(item, employee);
            throw new BusinessException("Nhan vien da bi xoa - can admin xu ly", 409);
        }
        return employee;
    }

    private void notifyDeletedEmployeeSyncFailure(AttendanceSyncItemRequest item, UserEntity employee) {
        log.warn("Offline attendance sync failed because employee was deleted: employeeId={}, localLogId={}, mobileCheckTime={}",
                item.employeeId(), item.localLogId(), mobileCheckTime(item));
        notificationService.sendToRoles(
                List.of(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.MANAGER),
                NotificationType.ATTENDANCE_SYNC_FAILED,
                "Can kiem tra cham cong offline",
                "Log offline bi tu choi vi nhan vien da bi xoa: "
                        + employee.getEmployeeCode()
                        + " - "
                        + employee.getFullName(),
                "ATTENDANCE_OFFLINE_SYNC",
                item.localLogId(),
                true);
    }

    private double verifyOfflineFaceEmbedding(UserEntity employee, AttendanceSyncItemRequest item, UUID syncedByUserId) {
        if (!Boolean.TRUE.equals(employee.getFaceEnrolled()) || employee.getFaceEncoding() == null) {
            throw new BusinessException("Nhan vien chua dang ky khuon mat", 400);
        }
        if (item.faceImageBase64() == null || item.faceImageBase64().isBlank()) {
            throw new BusinessException("Thieu anh goc khuon mat de server xac minh offline", 400);
        }
        FaceRecognitionService.FaceVerificationResult verification = faceRecognitionService.verify(
                employee.getFaceEncoding(),
                item.faceImageBase64(),
                item.imageContentType());
        faceRecognitionMonitoringService.recordServerSyncAttempt(
                employee.getId(),
                employee.getFullName(),
                syncedByUserId,
                item.deviceId(),
                "face-embedding",
                verification.matched(),
                verification.confidence(),
                faceMatchThreshold);
        if (!verification.matched()) {
            throw new BusinessException("Server khong xac minh duoc anh khuon mat offline", 403);
        }
        return verification.confidence();
    }

    private Instant mobileCheckTime(AttendanceSyncItemRequest item) {
        return item.mobileCheckTime() != null ? item.mobileCheckTime() : item.checkTime();
    }

    private long elapsedMs(long startedAtNanos) {
        return (System.nanoTime() - startedAtNanos) / 1_000_000;
    }

    private String lowConfidenceMessage(double score) {
        return "Xác minh khuôn mặt thất bại: độ khớp chưa đủ tin cậy "
                + "(độ khớp "
                + percent(score)
                + ", yêu cầu tối thiểu "
                + percent(faceMatchThreshold)
                + "). Vui lòng quét lại với ánh sáng tốt hơn hoặc nhìn thẳng vào camera.";
    }

    private String ambiguousFaceMessage(double bestScore, double secondBestScore) {
        return "Ket qua nhan dien khong ro rang vi khuon mat gan giong nhieu nhan vien "
                + "(cao nhat "
                + percent(bestScore)
                + ", ung vien tiep theo "
                + percent(secondBestScore)
                + "). Vui long quet lai hoac lien he quan ly de dang ky lai khuon mat.";
    }

    private String percent(double value) {
        return String.format(Locale.US, "%.1f%%", value * 100.0);
    }

    private void logAttendanceDecision(
            String event,
            UUID employeeId,
            String deviceId,
            Double score,
            long latencyMs,
            String result,
            String attendanceType,
            UUID recordId) {
        putMdc("event", event);
        putMdc("emp_id", employeeId);
        putMdc("device_id", deviceId);
        putMdc("score", score == null ? null : String.format(java.util.Locale.US, "%.6f", score));
        putMdc("latency_ms", Long.toString(latencyMs));
        putMdc("result", result);
        putMdc("attendance_type", attendanceType);
        putMdc("attendance_record_id", recordId);
        try {
            if (result != null && (result.startsWith("FAILED") || result.startsWith("REJECTED"))) {
                log.warn("{} result={}", event, result);
            } else {
                log.info("{} result={}", event, result);
            }
        } finally {
            MDC.remove("event");
            MDC.remove("emp_id");
            MDC.remove("device_id");
            MDC.remove("score");
            MDC.remove("latency_ms");
            MDC.remove("result");
            MDC.remove("attendance_type");
            MDC.remove("attendance_record_id");
        }
    }

    private void putMdc(String key, Object value) {
        if (value != null) {
            MDC.put(key, value.toString());
        }
    }

    @Transactional(readOnly = true)
    public DailyAttendanceResponse getMyToday(UUID employeeId) {
        return getDaily(employeeId, LocalDate.now(BUSINESS_ZONE));
    }

    @Transactional(readOnly = true)
    public DailyAttendanceResponse getDaily(UUID employeeId, LocalDate date) {
        findUser(employeeId);
        List<AttendanceRecord> records = attendanceRecordRepository
                .findTodayRecords(employeeId, startOfDay(date), startOfDay(date.plusDays(1)))
                .stream()
                .filter(record -> Boolean.TRUE.equals(record.getIsValid()))
                .sorted(Comparator.comparing(AttendanceRecord::getCheckTime))
                .toList();

        WorkSchedule schedule = workScheduleRepository
                .findByEmployeeIdAndWorkDateAndIsDeletedFalse(employeeId, date)
                .orElse(null);

        return toDailyResponse(date, records, schedule);
    }

    @Transactional(readOnly = true)
    public Page<AttendanceResponse> getHistory(UUID employeeId, LocalDate from, LocalDate to, Pageable pageable) {
        UserEntity employee = findUser(employeeId);
        LocalDate startDate = from != null ? from : LocalDate.now(BUSINESS_ZONE).minusDays(30);
        LocalDate endDate = to != null ? to : LocalDate.now(BUSINESS_ZONE);
        if (endDate.isBefore(startDate)) {
            throw new BusinessException("Ngày kết thúc phải sau hoặc bằng ngày bắt đầu");
        }

        return attendanceRecordRepository
                .findByEmployeeAndDateRange(employeeId, startOfDay(startDate), startOfDay(endDate.plusDays(1)), pageable)
                .map(record -> toAttendanceResponse(record, employee));
    }

    @Transactional(readOnly = true)
    public List<DailyAttendanceResponse> getReport(LocalDate date) {
        LocalDate reportDate = date != null ? date : LocalDate.now(BUSINESS_ZONE);
        List<UUID> allowedUserIds = userRepository.findAll().stream()
                .filter(u -> !Boolean.TRUE.equals(u.getIsDeleted()))
                .filter(u -> u.getRole() != UserRole.ADMIN && u.getRole() != UserRole.SUPER_ADMIN)
                .map(UserEntity::getId)
                .toList();

        List<AttendanceRecord> records = attendanceRecordRepository
                .findAllByDate(startOfDay(reportDate), startOfDay(reportDate.plusDays(1)))
                .stream()
                .filter(record -> Boolean.TRUE.equals(record.getIsValid()))
                .filter(record -> allowedUserIds.contains(record.getEmployeeId()))
                .toList();

        Map<UUID, List<AttendanceRecord>> byEmployee = records.stream()
                .collect(Collectors.groupingBy(AttendanceRecord::getEmployeeId));
        Map<UUID, WorkSchedule> schedules = workScheduleRepository.findByWorkDateAndIsDeletedFalse(reportDate)
                .stream()
                .filter(schedule -> allowedUserIds.contains(schedule.getEmployeeId()))
                .collect(Collectors.toMap(WorkSchedule::getEmployeeId, schedule -> schedule));

        return byEmployee.entrySet().stream()
                .map(entry -> toDailyResponse(reportDate,
                        entry.getValue().stream()
                                .sorted(Comparator.comparing(AttendanceRecord::getCheckTime))
                                .toList(),
                        schedules.get(entry.getKey())))
                .toList();
    }

    @Transactional
    public WorkScheduleResponse createOrUpdateSchedule(CreateScheduleRequest request) {
        UserEntity employee = findUser(request.employeeId());
        if (!request.shiftEnd().isAfter(request.shiftStart())) {
            throw new BusinessException("Giờ kết thúc ca phải sau giờ bắt đầu");
        }

        WorkSchedule schedule = workScheduleRepository
                .findByEmployeeIdAndWorkDateAndIsDeletedFalse(request.employeeId(), request.workDate())
                .orElseGet(WorkSchedule::new);

        schedule.setEmployeeId(request.employeeId());
        schedule.setWorkDate(request.workDate());
        schedule.setShiftStart(request.shiftStart());
        schedule.setShiftEnd(request.shiftEnd());
        schedule.setNote(request.note());

        return toScheduleResponse(workScheduleRepository.save(schedule), employee);
    }

    @Transactional(readOnly = true)
    public List<WorkScheduleResponse> getSchedules(UUID employeeId, LocalDate from, LocalDate to) {
        UserEntity employee = findUser(employeeId);
        LocalDate startDate = from != null ? from : LocalDate.now(BUSINESS_ZONE).minusDays(7);
        LocalDate endDate = to != null ? to : LocalDate.now(BUSINESS_ZONE).plusDays(30);

        return workScheduleRepository.findByEmployeeAndDateRange(employeeId, startDate, endDate)
                .stream()
                .map(schedule -> toScheduleResponse(schedule, employee))
                .toList();
    }

    private DailyAttendanceResponse toDailyResponse(LocalDate date, List<AttendanceRecord> records, WorkSchedule schedule) {
        Instant checkIn = records.stream()
                .filter(record -> record.getType() == AttendanceType.IN)
                .map(AttendanceRecord::getCheckTime)
                .min(Instant::compareTo)
                .orElse(null);
        Instant checkOut = records.stream()
                .filter(record -> record.getType() == AttendanceType.OUT)
                .map(AttendanceRecord::getCheckTime)
                .max(Instant::compareTo)
                .orElse(null);

        LocalTime shiftStart = schedule != null ? schedule.getShiftStart() : DEFAULT_SHIFT_START;
        LocalTime shiftEnd = schedule != null ? schedule.getShiftEnd() : DEFAULT_SHIFT_END;
        Instant shiftStartInstant = date.atTime(shiftStart).atZone(BUSINESS_ZONE).toInstant();
        Instant shiftEndInstant = date.atTime(shiftEnd).atZone(BUSINESS_ZONE).toInstant();

        Long totalMinutes = checkIn != null && checkOut != null
                ? Duration.between(checkIn, checkOut).toMinutes()
                : null;

        return new DailyAttendanceResponse(
                date,
                checkIn,
                checkOut,
                totalMinutes,
                checkIn != null && checkIn.isAfter(shiftStartInstant.plus(LATE_GRACE)),
                checkOut != null && checkOut.isBefore(shiftEndInstant),
                shiftStart.toString(),
                shiftEnd.toString(),
                records.stream().map(record -> toAttendanceResponse(record, null)).toList()
        );
    }

    private AttendanceResponse toAttendanceResponse(AttendanceRecord record, UserEntity knownEmployee) {
        UserEntity employee = knownEmployee != null ? knownEmployee : userRepository
                .findByIdAndIsDeletedFalse(record.getEmployeeId())
                .orElse(null);

        return new AttendanceResponse(
                record.getId(),
                record.getEmployeeId(),
                employee != null ? employee.getFullName() : "Khong xac dinh",
                employee != null ? employee.getEmployeeCode() : null,
                employee != null ? employee.getAvatarUrl() : null,
                record.getType().name(),
                record.getCheckTime(),
                record.getMobileCheckTime(),
                record.getConfidenceScore(),
                record.getFaceImagePath(),
                record.getIsValid(),
                record.getNote()
        );
    }

    private WorkScheduleResponse toScheduleResponse(WorkSchedule schedule, UserEntity employee) {
        return new WorkScheduleResponse(
                schedule.getId(),
                schedule.getEmployeeId(),
                employee.getFullName(),
                schedule.getWorkDate(),
                schedule.getShiftStart(),
                schedule.getShiftEnd(),
                schedule.getNote()
        );
    }

    private UserEntity findUser(UUID userId) {
        return userRepository.findByIdAndIsDeletedFalse(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay nhan vien: " + userId));
    }

    private Instant startOfDay(LocalDate date) {
        return date.atStartOfDay(BUSINESS_ZONE).toInstant();
    }

    private record FaceCandidate(UserEntity employee, double score) {
    }

    @Transactional
    public AttendanceResponse updateRecord(UUID recordId, UpdateAttendanceRecordRequest request, UUID updatedByUserId) {
        AttendanceRecord record = attendanceRecordRepository.findById(recordId)
                .filter(r -> !Boolean.TRUE.equals(r.getIsDeleted()))
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy bản ghi chấm công hoặc bản ghi đã bị xóa"));

        record.setCheckTime(request.checkTime());
        if (request.isValid() != null) {
            record.setIsValid(request.isValid());
        }
        if (request.note() != null) {
            record.setNote(request.note());
        }
        record.setUpdatedBy(updatedByUserId);

        AttendanceRecord saved = attendanceRecordRepository.save(record);
        UserEntity employee = userRepository.findByIdAndIsDeletedFalse(saved.getEmployeeId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên liên kết"));

        log.info("Attendance record updated: recordId={}, employeeId={}, by={}",
                recordId, saved.getEmployeeId(), updatedByUserId);
        return toAttendanceResponse(saved, employee);
    }

    @Transactional
    public void deleteRecord(UUID recordId, UUID deletedByUserId) {
        AttendanceRecord record = attendanceRecordRepository.findById(recordId)
                .filter(r -> !Boolean.TRUE.equals(r.getIsDeleted()))
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy bản ghi chấm công hoặc bản ghi đã bị xóa"));

        record.softDelete(deletedByUserId);
        attendanceRecordRepository.save(record);
        log.info("Attendance record soft deleted: recordId={}, employeeId={}, by={}",
                recordId, record.getEmployeeId(), deletedByUserId);
    }
}
