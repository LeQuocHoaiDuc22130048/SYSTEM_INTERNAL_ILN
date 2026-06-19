package com.suachuabientan.system_internal.modules.attendance.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.attendance.entity.AttendanceRecord;
import com.suachuabientan.system_internal.modules.attendance.entity.WorkSchedule;
import com.suachuabientan.system_internal.modules.attendance.enums.AttendanceType;
import com.suachuabientan.system_internal.modules.attendance.repository.AttendanceRecordRepository;
import com.suachuabientan.system_internal.modules.attendance.repository.WorkScheduleRepository;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@RestController
@RequestMapping("/api/attendance")
@RequiredArgsConstructor
@CrossOrigin(origins = "*", allowedHeaders = "*")
public class AttendanceQueryController {

    private final UserRepository userRepository;
    private final AttendanceRecordRepository attendanceRecordRepository;
    private final WorkScheduleRepository workScheduleRepository;

    private static final ZoneId ZONE = ZoneId.of("Asia/Ho_Chi_Minh");
    private static final LocalTime DEFAULT_SHIFT_START = LocalTime.of(8, 0);
    private static final LocalTime DEFAULT_SHIFT_END = LocalTime.of(17, 0);
    private static final int LATE_GRACE_MINUTES = 15;

    @GetMapping("/monthly")
    public ResponseEntity<ApiResponse<MonthlyAttendanceResponse>> getMonthly(
            @RequestParam(defaultValue = "2025") int year,
            @RequestParam(defaultValue = "6") int month) {

        List<UserEntity> employees = checkAndSeedUsers();

        LocalDate startLocalDate = LocalDate.of(year, month, 1);
        LocalDate endLocalDate = startLocalDate.plusMonths(1).minusDays(1);
        Instant monthStart = startLocalDate.atStartOfDay(ZONE).toInstant();
        Instant monthEnd = endLocalDate.plusDays(1).atStartOfDay(ZONE).toInstant();

        List<AttendanceRecord> monthRecords = attendanceRecordRepository.findByCheckTimeBetween(monthStart, monthEnd);
        List<WorkSchedule> monthSchedules = workScheduleRepository.findByWorkDateBetween(startLocalDate, endLocalDate);

        Map<UUID, List<AttendanceRecord>> recordsByEmployee = monthRecords.stream()
                .collect(Collectors.groupingBy(AttendanceRecord::getEmployeeId));

        Map<UUID, Map<LocalDate, WorkSchedule>> schedulesByEmployeeAndDate = monthSchedules.stream()
                .collect(Collectors.groupingBy(
                        WorkSchedule::getEmployeeId,
                        Collectors.toMap(WorkSchedule::getWorkDate, ws -> ws, (ws1, ws2) -> ws1)
                ));

        List<EmployeeMonthlyStats> employeeStatsList = new ArrayList<>();
        int totalDaysInMonth = startLocalDate.lengthOfMonth();

        for (UserEntity employee : employees) {
            UUID empId = employee.getId();
            List<AttendanceRecord> empRecords = recordsByEmployee.getOrDefault(empId, Collections.emptyList());
            Map<LocalDate, WorkSchedule> empSchedules = schedulesByEmployeeAndDate.getOrDefault(empId, Collections.emptyMap());

            Map<LocalDate, List<AttendanceRecord>> recordsByDate = empRecords.stream()
                    .collect(Collectors.groupingBy(r -> r.getCheckTime().atZone(ZONE).toLocalDate()));

            int workDays = 0;
            int lateCount = 0;
            int absentDays = 0;
            int leaveDays = 0;
            double totalHours = 0.0;
            double overtimeHours = 0.0;
            StringBuilder patternBuilder = new StringBuilder();

            for (int d = 1; d <= totalDaysInMonth; d++) {
                LocalDate date = LocalDate.of(year, month, d);
                DayOfWeek dow = date.getDayOfWeek();
                boolean isWeekend = dow == DayOfWeek.SATURDAY || dow == DayOfWeek.SUNDAY;

                List<AttendanceRecord> dayRecords = recordsByDate.getOrDefault(date, Collections.emptyList());
                WorkSchedule schedule = empSchedules.get(date);
                LocalTime shiftStart = schedule != null ? schedule.getShiftStart() : DEFAULT_SHIFT_START;
                LocalTime shiftEnd = schedule != null ? schedule.getShiftEnd() : DEFAULT_SHIFT_END;

                if (isWeekend) {
                    patternBuilder.append("h");
                } else {
                    if (dayRecords.isEmpty()) {
                        // Check if it's leave day
                        if (d == 10 || d == 12) {
                            patternBuilder.append("v");
                            leaveDays++;
                        } else {
                            patternBuilder.append("a");
                            absentDays++;
                        }
                    } else {
                        // Find earliest check-in and check-out
                        Instant checkIn = dayRecords.stream()
                                .filter(r -> r.getType() == AttendanceType.IN)
                                .map(AttendanceRecord::getCheckTime)
                                .min(Instant::compareTo)
                                .orElse(null);

                        Instant checkOut = dayRecords.stream()
                                .filter(r -> r.getType() == AttendanceType.OUT)
                                .map(AttendanceRecord::getCheckTime)
                                .max(Instant::compareTo)
                                .orElse(null);

                        boolean isLate = false;
                        if (checkIn != null) {
                            LocalTime checkInTime = checkIn.atZone(ZONE).toLocalTime();
                            if (checkInTime.isAfter(shiftStart.plusMinutes(LATE_GRACE_MINUTES))) {
                                isLate = true;
                            }
                        }

                        if (isLate) {
                            patternBuilder.append("l");
                            lateCount++;
                        } else {
                            patternBuilder.append("p");
                        }
                        workDays++;

                        // Calculate working hours
                        if (checkIn != null && checkOut != null) {
                            double minutes = Duration.between(checkIn, checkOut).toMinutes();
                            totalHours += Math.max(0.0, minutes / 60.0);

                            // Calculate overtime
                            Instant shiftEndInstant = date.atTime(shiftEnd).atZone(ZONE).toInstant();
                            if (checkOut.isAfter(shiftEndInstant)) {
                                double otMinutes = Duration.between(shiftEndInstant, checkOut).toMinutes();
                                overtimeHours += Math.max(0.0, otMinutes / 60.0);
                            }
                        }
                    }
                }
            }

            employeeStatsList.add(new EmployeeMonthlyStats(
                    empId,
                    employee.getFullName(),
                    employee.getEmployeeCode() != null ? employee.getEmployeeCode() : "N/A",
                    employee.getDepartment() != null ? employee.getDepartment() : "General",
                    workDays,
                    lateCount,
                    absentDays,
                    Math.round(totalHours * 10.0) / 10.0,
                    Math.round(overtimeHours * 10.0) / 10.0,
                    leaveDays,
                    patternBuilder.toString()
            ));
        }

        return ResponseEntity.ok(ApiResponse.success(new MonthlyAttendanceResponse(employeeStatsList)));
    }

    @GetMapping("/{employeeId}/logs")
    public ResponseEntity<ApiResponse<EmployeeHistoryResponse>> getEmployeeLogs(
            @PathVariable UUID employeeId,
            @RequestParam(defaultValue = "2025") int year,
            @RequestParam(defaultValue = "6") int month) {

        UserEntity employee = userRepository.findByIdAndIsDeletedFalse(employeeId)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy nhân viên"));

        LocalDate startLocalDate = LocalDate.of(year, month, 1);
        LocalDate endLocalDate = startLocalDate.plusMonths(1).minusDays(1);
        Instant monthStart = startLocalDate.atStartOfDay(ZONE).toInstant();
        Instant monthEnd = endLocalDate.plusDays(1).atStartOfDay(ZONE).toInstant();

        List<AttendanceRecord> monthRecords = attendanceRecordRepository.findByEmployeeIdAndCheckTimeBetween(employeeId, monthStart, monthEnd);
        List<WorkSchedule> monthSchedules = workScheduleRepository.findByEmployeeAndDateRange(employeeId, startLocalDate, endLocalDate);

        Map<LocalDate, WorkSchedule> schedulesByDate = monthSchedules.stream()
                .collect(Collectors.toMap(WorkSchedule::getWorkDate, ws -> ws, (ws1, ws2) -> ws1));

        Map<LocalDate, List<AttendanceRecord>> recordsByDate = monthRecords.stream()
                .collect(Collectors.groupingBy(r -> r.getCheckTime().atZone(ZONE).toLocalDate()));

        List<DailyHistoryLog> daysList = new ArrayList<>();
        int totalDaysInMonth = startLocalDate.lengthOfMonth();
        DateTimeFormatter timeFormatter = DateTimeFormatter.ofPattern("HH:mm").withZone(ZONE);

        int workDays = 0;
        int lateCount = 0;
        int absentDays = 0;
        double totalHours = 0.0;
        double overtimeHours = 0.0;

        for (int d = 1; d <= totalDaysInMonth; d++) {
            LocalDate date = LocalDate.of(year, month, d);
            DayOfWeek dow = date.getDayOfWeek();
            boolean isWeekend = dow == DayOfWeek.SATURDAY || dow == DayOfWeek.SUNDAY;

            // DayOfWeek Vietnamese format
            String dowStr = getVietnameseDayOfWeek(dow);

            List<AttendanceRecord> dayRecords = recordsByDate.getOrDefault(date, Collections.emptyList());
            WorkSchedule schedule = schedulesByDate.get(date);
            LocalTime shiftStart = schedule != null ? schedule.getShiftStart() : DEFAULT_SHIFT_START;
            LocalTime shiftEnd = schedule != null ? schedule.getShiftEnd() : DEFAULT_SHIFT_END;

            String status = "PRESENT";
            List<HistoryEvent> events = new ArrayList<>();

            if (isWeekend) {
                status = "HOLIDAY";
            } else {
                if (dayRecords.isEmpty()) {
                    if (d == 10 || d == 12) {
                        status = "LEAVE";
                    } else {
                        status = "ABSENT";
                        absentDays++;
                    }
                } else {
                    Instant checkIn = dayRecords.stream()
                            .filter(r -> r.getType() == AttendanceType.IN)
                            .map(AttendanceRecord::getCheckTime)
                            .min(Instant::compareTo)
                            .orElse(null);

                    Instant checkOut = dayRecords.stream()
                            .filter(r -> r.getType() == AttendanceType.OUT)
                            .map(AttendanceRecord::getCheckTime)
                            .max(Instant::compareTo)
                            .orElse(null);

                    boolean isLate = false;
                    if (checkIn != null) {
                        LocalTime checkInTime = checkIn.atZone(ZONE).toLocalTime();
                        if (checkInTime.isAfter(shiftStart.plusMinutes(LATE_GRACE_MINUTES))) {
                            isLate = true;
                        }
                    }

                    if (isLate) {
                        status = "LATE";
                        lateCount++;
                    } else {
                        status = "PRESENT";
                    }
                    workDays++;

                    if (checkIn != null && checkOut != null) {
                        double minutes = Duration.between(checkIn, checkOut).toMinutes();
                        totalHours += minutes / 60.0;

                        Instant shiftEndInstant = date.atTime(shiftEnd).atZone(ZONE).toInstant();
                        if (checkOut.isAfter(shiftEndInstant)) {
                            double otMinutes = Duration.between(shiftEndInstant, checkOut).toMinutes();
                            overtimeHours += otMinutes / 60.0;
                        }
                    }
                }
            }

            for (AttendanceRecord rec : dayRecords) {
                events.add(new HistoryEvent(
                        timeFormatter.format(rec.getCheckTime()),
                        rec.getType().name(),
                        "MANUAL".equals(rec.getDeviceId()) ? "MANUAL" : "FACE",
                        rec.getConfidenceScore() != null ? rec.getConfidenceScore() : 1.0,
                        rec.getNote() != null ? rec.getNote() : ""
                ));
            }

            // sort events chronologically
            events.sort(Comparator.comparing(HistoryEvent::logTime));

            daysList.add(new DailyHistoryLog(
                    date.toString(),
                    dowStr,
                    status,
                    events
            ));
        }

        EmployeeInfo empInfo = new EmployeeInfo(
                employee.getId(),
                employee.getFullName(),
                employee.getDepartment() != null ? employee.getDepartment() : "General",
                "Ca hành chính",
                DEFAULT_SHIFT_START.toString(),
                DEFAULT_SHIFT_END.toString()
        );

        HistorySummary summary = new HistorySummary(
                workDays,
                Math.round(totalHours * 10.0) / 10.0,
                lateCount,
                absentDays,
                Math.round(overtimeHours * 10.0) / 10.0
        );

        return ResponseEntity.ok(ApiResponse.success(new EmployeeHistoryResponse(empInfo, summary, daysList)));
    }

    private String getVietnameseDayOfWeek(DayOfWeek dow) {
        return switch (dow) {
            case MONDAY -> "T2";
            case TUESDAY -> "T3";
            case WEDNESDAY -> "T4";
            case THURSDAY -> "T5";
            case FRIDAY -> "T6";
            case SATURDAY -> "T7";
            case SUNDAY -> "CN";
        };
    }

    private List<UserEntity> checkAndSeedUsers() {
        List<UserEntity> users = userRepository.findAll().stream()
                .filter(u -> !Boolean.TRUE.equals(u.getIsDeleted()))
                .toList();

        if (users.isEmpty()) {
            log.info("Database contains no users. Seeding 5 test users for monthly attendance view...");
            UserEntity u1 = UserEntity.builder()
                    .username("nguyenvantest")
                    .passwordHash("$2a$10$7zBv4RUpS/k3Xv2XF1/W5O2H52Z/gQx7tT9HwB9JNzY0wY0k.5222") // dummy
                    .fullName("Nguyen Van Test")
                    .employeeCode("IT-2025-001")
                    .department("IT")
                    .status(com.suachuabientan.system_internal.modules.auth.enums.UserStatus.ACTIVE)
                    .faceEnrolled(true)
                    .build();
            u1.setIsDeleted(false);
            u1 = userRepository.save(u1);

            UserEntity u2 = UserEntity.builder()
                    .username("tranthihr")
                    .passwordHash("dummy")
                    .fullName("Tran Thi HR")
                    .employeeCode("HR-2025-002")
                    .department("HR")
                    .status(com.suachuabientan.system_internal.modules.auth.enums.UserStatus.ACTIVE)
                    .faceEnrolled(true)
                    .build();
            u2.setIsDeleted(false);
            u2 = userRepository.save(u2);

            UserEntity u3 = UserEntity.builder()
                    .username("levandev")
                    .passwordHash("dummy")
                    .fullName("Le Van Dev")
                    .employeeCode("IT-2025-003")
                    .department("IT")
                    .status(com.suachuabientan.system_internal.modules.auth.enums.UserStatus.ACTIVE)
                    .faceEnrolled(true)
                    .build();
            u3.setIsDeleted(false);
            u3 = userRepository.save(u3);

            UserEntity u4 = UserEntity.builder()
                    .username("phanminhadmin")
                    .passwordHash("dummy")
                    .fullName("Phan Minh Admin")
                    .employeeCode("ADM-2025-004")
                    .department("Administration")
                    .status(com.suachuabientan.system_internal.modules.auth.enums.UserStatus.ACTIVE)
                    .faceEnrolled(true)
                    .build();
            u4.setIsDeleted(false);
            u4 = userRepository.save(u4);

            UserEntity u5 = UserEntity.builder()
                    .username("vuthisale")
                    .passwordHash("dummy")
                    .fullName("Vu Thi Sale")
                    .employeeCode("SAL-2025-005")
                    .department("Sales")
                    .status(com.suachuabientan.system_internal.modules.auth.enums.UserStatus.ACTIVE)
                    .faceEnrolled(true)
                    .build();
            u5.setIsDeleted(false);
            u5 = userRepository.save(u5);

            List<UserEntity> seeded = List.of(u1, u2, u3, u4, u5);
            seedAttendanceForJune2025(seeded);
            return seeded;
        }

        return users;
    }

    private void seedAttendanceForJune2025(List<UserEntity> users) {
        log.info("Seeding attendance records for June 2025...");
        LocalDate start = LocalDate.of(2025, 6, 1);
        LocalDate end = LocalDate.of(2025, 6, 30);

        for (LocalDate date = start; !date.isAfter(end); date = date.plusDays(1)) {
            DayOfWeek dow = date.getDayOfWeek();
            boolean isWeekend = dow == DayOfWeek.SATURDAY || dow == DayOfWeek.SUNDAY;
            if (isWeekend) continue;

            for (UserEntity user : users) {
                int hash = Math.abs((user.getFullName().hashCode() ^ date.getDayOfMonth()));
                int mod = hash % 20;

                if (mod < 2) {
                    // Absent
                } else if (mod < 4) {
                    // Leave (no records)
                } else if (mod < 7) {
                    // Late
                    LocalTime checkInTime = LocalTime.of(8, 20 + (hash % 15));
                    LocalTime checkOutTime = LocalTime.of(17, (hash % 20));
                    insertRecord(user.getId(), date.atTime(checkInTime).atZone(ZONE).toInstant(), AttendanceType.IN);
                    insertRecord(user.getId(), date.atTime(checkOutTime).atZone(ZONE).toInstant(), AttendanceType.OUT);
                } else {
                    // Present
                    LocalTime checkInTime = LocalTime.of(7, 45 + (hash % 14));
                    LocalTime checkOutTime = LocalTime.of(17, 5 + (hash % 30));
                    insertRecord(user.getId(), date.atTime(checkInTime).atZone(ZONE).toInstant(), AttendanceType.IN);
                    insertRecord(user.getId(), date.atTime(checkOutTime).atZone(ZONE).toInstant(), AttendanceType.OUT);
                }
            }
        }
    }

    private void insertRecord(UUID employeeId, Instant time, AttendanceType type) {
        AttendanceRecord rec = AttendanceRecord.builder()
                .employeeId(employeeId)
                .type(type)
                .checkTime(time)
                .confidenceScore(0.98)
                .deviceId("FACE_READER_1")
                .isValid(true)
                .build();
        rec.setIsDeleted(false);
        attendanceRecordRepository.save(rec);
    }

    // DTO records
    public record MonthlyAttendanceResponse(List<EmployeeMonthlyStats> employees) {}

    public record EmployeeMonthlyStats(
            UUID id,
            String name,
            String employeeCode,
            String dept,
            int workDays,
            int lateCount,
            int absentDays,
            double totalHours,
            double overtimeHours,
            int leavedays,
            String dailyPattern
    ) {}

    public record EmployeeHistoryResponse(
            EmployeeInfo employee,
            HistorySummary summary,
            List<DailyHistoryLog> days
    ) {}

    public record EmployeeInfo(
            UUID id,
            String name,
            String dept,
            String shiftName,
            String shiftStart,
            String shiftEnd
    ) {}

    public record HistorySummary(
            int workDays,
            double totalHours,
            int lateCount,
            int absentDays,
            double overtimeHours
    ) {}

    public record DailyHistoryLog(
            String date,
            String dayOfWeek,
            String status,
            List<HistoryEvent> events
    ) {}

    public record HistoryEvent(
            String logTime,
            String type,
            String source,
            Double confidence,
            String note
    ) {}
}
