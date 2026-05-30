package com.suachuabientan.system_internal.modules.attendance.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.attendance.dto.request.CheckinRequest;
import com.suachuabientan.system_internal.modules.attendance.dto.request.CreateScheduleRequest;
import com.suachuabientan.system_internal.modules.attendance.dto.request.FaceCheckinRequest;
import com.suachuabientan.system_internal.modules.attendance.dto.request.ManualCheckinRequest;
import com.suachuabientan.system_internal.modules.attendance.dto.response.AttendanceResponse;
import com.suachuabientan.system_internal.modules.attendance.dto.response.DailyAttendanceResponse;
import com.suachuabientan.system_internal.modules.attendance.dto.response.WorkScheduleResponse;
import com.suachuabientan.system_internal.modules.attendance.entity.AttendanceRecord;
import com.suachuabientan.system_internal.modules.attendance.entity.WorkSchedule;
import com.suachuabientan.system_internal.modules.attendance.enums.AttendanceType;
import com.suachuabientan.system_internal.modules.attendance.repository.AttendanceRecordRepository;
import com.suachuabientan.system_internal.modules.attendance.repository.WorkScheduleRepository;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
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
import java.util.List;
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
    private static final Duration LATE_GRACE = Duration.ofMinutes(5);

    private final AttendanceRecordRepository attendanceRecordRepository;
    private final WorkScheduleRepository workScheduleRepository;
    private final UserRepository userRepository;
    private final FaceRecognitionService faceRecognitionService;

    @Transactional
    public AttendanceResponse check(UUID employeeId, CheckinRequest request) {
        UserEntity employee = findUser(employeeId);
        return recordAttendance(employee, request.deviceId(), request.note(), null);
    }

    @Transactional
    public AttendanceResponse faceCheck(UUID employeeId, FaceCheckinRequest request) {
        UserEntity employee = findUser(employeeId);
        if (!Boolean.TRUE.equals(employee.getFaceEnrolled()) || employee.getFaceEncoding() == null) {
            throw new BusinessException("Nhân viên chưa đăng ký khuôn mặt", 400);
        }

        FaceRecognitionService.FaceVerificationResult verification = faceRecognitionService.verify(
                employee.getFaceEncoding(),
                request.faceImageBase64(),
                request.imageContentType());
        if (!verification.matched()) {
            throw new BusinessException("Không xác minh được khuôn mặt", 403);
        }

        return recordAttendance(
                employee,
                request.deviceId(),
                "Chấm công bằng khuôn mặt từ ứng dụng",
                verification.confidence());
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
        List<AttendanceRecord> records = attendanceRecordRepository
                .findAllByDate(startOfDay(reportDate), startOfDay(reportDate.plusDays(1)))
                .stream()
                .filter(record -> Boolean.TRUE.equals(record.getIsValid()))
                .toList();

        Map<UUID, List<AttendanceRecord>> byEmployee = records.stream()
                .collect(Collectors.groupingBy(AttendanceRecord::getEmployeeId));
        Map<UUID, WorkSchedule> schedules = workScheduleRepository.findByWorkDateAndIsDeletedFalse(reportDate)
                .stream()
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
}
