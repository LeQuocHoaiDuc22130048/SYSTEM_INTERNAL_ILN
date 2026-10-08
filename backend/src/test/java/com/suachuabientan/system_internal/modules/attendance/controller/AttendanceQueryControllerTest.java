package com.suachuabientan.system_internal.modules.attendance.controller;

import com.suachuabientan.system_internal.common.util.JwtUtil;
import com.suachuabientan.system_internal.config.SecurityConfig;
import com.suachuabientan.system_internal.modules.attendance.repository.AttendanceRecordRepository;
import com.suachuabientan.system_internal.modules.attendance.repository.WorkScheduleRepository;
import com.suachuabientan.system_internal.modules.attendance.entity.AttendanceRecord;
import com.suachuabientan.system_internal.modules.attendance.enums.AttendanceType;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.enums.UserStatus;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.security.filter.JwtAuthFilter;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import com.suachuabientan.system_internal.security.service.UserDetailsServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.security.test.context.support.WithUserDetails;
import org.springframework.security.test.context.support.TestExecutionEvent;
import org.springframework.test.web.servlet.MockMvc;
import jakarta.servlet.FilterChain;
import org.mockito.Mockito;

import java.util.Collections;
import java.util.Optional;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(AttendanceQueryController.class)
@Import(SecurityConfig.class)
class AttendanceQueryControllerTest {
    @MockBean
    private com.suachuabientan.system_internal.modules.attendance.repository.FieldWorkDayRepository fieldWorkDayRepository;

    @org.junit.jupiter.params.ParameterizedTest
    @org.junit.jupiter.params.provider.ValueSource(booleans = {false, true})
    @WithMockUser(roles = "MANAGER")
    void fieldWorkCountsExactlyOneDayAndIncludesExcelNote(boolean withAttendance) throws Exception {
        UserEntity employee = new UserEntity();
        employee.setId(employeeId);
        employee.setRole(UserRole.EMPLOYEE);
        when(userRepository.findAll()).thenReturn(java.util.List.of(employee));
        when(userRepository.findByIdAndIsDeletedFalse(employeeId)).thenReturn(Optional.of(employee));
        var date = java.time.LocalDate.of(2026, 6, 7); // Sunday must still be exactly 1 day
        var field = new com.suachuabientan.system_internal.modules.attendance.entity.FieldWorkDay();
        field.setEmployeeId(employeeId);
        field.setWorkDate(date);
        field.setNote("Nhà máy ABC");
        when(fieldWorkDayRepository.findByWorkDateBetweenAndIsDeletedFalse(any(), any()))
                .thenReturn(java.util.List.of(field));
        when(fieldWorkDayRepository.findByEmployeeIdAndWorkDateBetweenAndIsDeletedFalseOrderByWorkDateAsc(any(), any(), any()))
                .thenReturn(java.util.List.of(field));
        var zone = java.time.ZoneId.of("Asia/Ho_Chi_Minh");
        var in = AttendanceRecord.builder().employeeId(employeeId).type(AttendanceType.IN)
                .checkTime(date.atTime(13, 54).atZone(zone).toInstant()).isValid(true).build();
        var out = AttendanceRecord.builder().employeeId(employeeId).type(AttendanceType.OUT)
                .checkTime(date.atTime(21, 30).atZone(zone).toInstant()).isValid(true).build();
        var records = withAttendance ? java.util.List.of(in, out) : java.util.List.<AttendanceRecord>of();
        when(attendanceRecordRepository.findByCheckTimeBetween(any(), any())).thenReturn(records);
        when(attendanceRecordRepository.findByEmployeeIdAndCheckTimeBetween(any(), any(), any())).thenReturn(records);
        mockMvc.perform(get("/api/attendance/monthly").param("year", "2026").param("month", "6"))
                .andExpect(status().isOk())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.data.employees[0].workDays").value(1.0))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.data.employees[0].dailyWorkDays.7").value(1.0))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.data.employees[0].updateNotes.7").value(org.hamcrest.Matchers.containsString("Đi công trình — Nhà máy ABC")))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.data.employees[0].lateCount").value(0));
        mockMvc.perform(get("/api/attendance/" + employeeId + "/logs").param("year", "2026").param("month", "6"))
                .andExpect(status().isOk())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.data.summary.workDays").value(1.0))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.data.days[6].status").value("FIELD_WORK"))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.data.days[6].note").value("Đi công trình — Nhà máy ABC"));
    }

    @org.junit.jupiter.params.ParameterizedTest
    @org.junit.jupiter.params.provider.CsvSource({"13, 54, 17, 49", "8, 54, 12, 0"})
    @WithMockUser(roles = "MANAGER")
    void lateHalfDayKeepsHalfWorkDayForExcel(int inHour, int inMinute, int outHour, int outMinute) throws Exception {
        UserEntity employee = new UserEntity();
        employee.setId(employeeId);
        employee.setRole(UserRole.EMPLOYEE);
        employee.setIsDeleted(false);
        when(userRepository.findAll()).thenReturn(java.util.List.of(employee));
        java.time.LocalDate date = java.time.LocalDate.of(2026, 9, 21);
        java.time.ZoneId zone = java.time.ZoneId.of("Asia/Ho_Chi_Minh");
        AttendanceRecord in = AttendanceRecord.builder().employeeId(employeeId).type(AttendanceType.IN)
                .checkTime(date.atTime(inHour, inMinute).atZone(zone).toInstant()).isValid(true).build();
        AttendanceRecord out = AttendanceRecord.builder().employeeId(employeeId).type(AttendanceType.OUT)
                .checkTime(date.atTime(outHour, outMinute).atZone(zone).toInstant()).isValid(true).build();
        when(attendanceRecordRepository.findByCheckTimeBetween(any(), any())).thenReturn(java.util.List.of(in, out));
        when(workScheduleRepository.findByWorkDateBetween(any(), any())).thenReturn(Collections.emptyList());
        mockMvc.perform(get("/api/attendance/monthly").param("year", "2026").param("month", "9"))
                .andExpect(status().isOk())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath(
                        "$.data.employees[0].workDays").value(0.5))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath(
                        "$.data.employees[0].lateCount").value(1))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath(
                        "$.data.employees[0].dailyWorkDays.21").value(0.5));
    }

    @org.junit.jupiter.params.ParameterizedTest
    @org.junit.jupiter.params.provider.CsvSource({
            "7, 8, 30, 17, 30, p, PRESENT, 1.5, 7.5",
            "7, 8, 30, 12, 0, m, HALF_DAY_MORNING, 1.5, 3.5",
            "7, 13, 30, 17, 30, c, HALF_DAY_AFTERNOON, 1.5, 4.0",
            "7, 8, 30, 21, 0, o, OVERTIME, 1.5, 11.0",
            "8, 13, 30, 21, 0, p, PRESENT, 1.0, 7.5",
            "8, 13, 30, 21, 30, p, PRESENT, 1.0, 8.0",
            "8, 13, 54, 21, 0, l, LATE, 1.0, 7.1",
            "8, 8, 30, 21, 0, o, OVERTIME, 1.5, 11.0",
            "8, 8, 30, 20, 59, p, PRESENT, 1.0, 11.0"
    })
    @WithMockUser(roles = "MANAGER")
    void attendanceCreditsMatchShiftsAndSundayInMonthlyAndHistory(
            int day, int inHour, int inMinute, int outHour, int outMinute,
            String pattern, String dayStatus, double workDays, double hours) throws Exception {
        UserEntity employee = new UserEntity();
        employee.setId(employeeId);
        employee.setRole(UserRole.EMPLOYEE);
        employee.setIsDeleted(false);
        when(userRepository.findAll()).thenReturn(java.util.List.of(employee));
        when(userRepository.findByIdAndIsDeletedFalse(employeeId)).thenReturn(Optional.of(employee));
        java.time.LocalDate date = java.time.LocalDate.of(2026, 6, day);
        java.time.ZoneId zone = java.time.ZoneId.of("Asia/Ho_Chi_Minh");
        AttendanceRecord in = AttendanceRecord.builder().employeeId(employeeId)
                .type(AttendanceType.IN).checkTime(date.atTime(inHour, inMinute).atZone(zone).toInstant())
                .isValid(true).build();
        AttendanceRecord out = AttendanceRecord.builder().employeeId(employeeId)
                .type(AttendanceType.OUT).checkTime(date.atTime(outHour, outMinute).atZone(zone).toInstant())
                .isValid(true).build();
        in.setIsDeleted(false);
        out.setIsDeleted(false);
        when(attendanceRecordRepository.findByCheckTimeBetween(any(), any()))
                .thenReturn(java.util.List.of(in, out));
        when(attendanceRecordRepository.findByEmployeeIdAndCheckTimeBetween(any(), any(), any()))
                .thenReturn(java.util.List.of(in, out));
        when(workScheduleRepository.findByWorkDateBetween(any(), any())).thenReturn(Collections.emptyList());
        when(workScheduleRepository.findByEmployeeAndDateRange(any(), any(), any())).thenReturn(Collections.emptyList());

        mockMvc.perform(get("/api/attendance/monthly").param("year", "2026").param("month", "6"))
                .andExpect(status().isOk())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath(
                        "$.data.employees[0].dailyPattern").value(day == 7
                                ? "aaaaaa" + pattern + "aaaaaahaaaaaahaaaaaahaa"
                                : "aaaaaah" + pattern + "aaaaahaaaaaahaaaaaahaa"))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath(
                        "$.data.employees[0].workDays").value(workDays))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath(
                        "$.data.employees[0].dailyWorkDays." + day).value(workDays))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath(
                        "$.data.employees[0].overtimeHours").value(pattern.equals("o") ? 3.5 : 0.0))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath(
                        "$.data.employees[0].totalHours").value(hours));
        mockMvc.perform(get("/api/attendance/" + employeeId + "/logs")
                        .param("year", "2026").param("month", "6"))
                .andExpect(status().isOk())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath(
                        "$.data.days[" + (day - 1) + "].status").value(dayStatus))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath(
                        "$.data.days[13].status").value("HOLIDAY"))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath(
                        "$.data.summary.workDays").value(workDays));
    }

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserRepository userRepository;

    @MockBean
    private AttendanceRecordRepository attendanceRecordRepository;

    @MockBean
    private WorkScheduleRepository workScheduleRepository;

    @MockBean
    private JwtAuthFilter jwtAuthFilter;

    @MockBean
    private UserDetailsServiceImpl userDetailsService;

    @MockBean
    private JwtUtil jwtUtil;

    private UUID employeeId;

    @BeforeEach
    void setUp() throws Exception {
        employeeId = UUID.randomUUID();
        SecurityContextHolder.clearContext();

        Mockito.doAnswer(invocation -> {
            jakarta.servlet.ServletRequest request = invocation.getArgument(0);
            jakarta.servlet.ServletResponse response = invocation.getArgument(1);
            FilterChain filterChain = invocation.getArgument(2);
            filterChain.doFilter(request, response);
            return null;
        }).when(jwtAuthFilter).doFilter(any(), any(), any());

        // Mock UserDetailsService trước khi @WithUserDetails chạy ở Test Lifecycle
        UserEntity employee = new UserEntity();
        employee.setId(employeeId);
        employee.setUsername("testemployee");
        employee.setRole(UserRole.EMPLOYEE);
        employee.setStatus(UserStatus.ACTIVE);

        CustomUserDetails userDetails = new CustomUserDetails(employee);
        when(userDetailsService.loadUserByUsername("testemployee")).thenReturn(userDetails);

        // MockUserRepository mặc định cho self test
        when(userRepository.findByIdAndIsDeletedFalse(employeeId)).thenReturn(Optional.of(employee));
    }

    @Test
    void getMonthlyWithoutAuthReturns403() throws Exception {
        mockMvc.perform(get("/api/attendance/monthly")
                .param("year", "2026")
                .param("month", "6"))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "EMPLOYEE")
    void getMonthlyWithEmployeeRoleReturns403() throws Exception {
        mockMvc.perform(get("/api/attendance/monthly")
                .param("year", "2026")
                .param("month", "6"))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "MANAGER")
    void getMonthlyWithManagerRoleSucceeds() throws Exception {
        UserEntity mockEmployee = new UserEntity();
        mockEmployee.setId(UUID.randomUUID());
        mockEmployee.setRole(UserRole.EMPLOYEE);
        mockEmployee.setIsDeleted(false);
        when(userRepository.findAll()).thenReturn(java.util.List.of(mockEmployee));
        when(attendanceRecordRepository.findByCheckTimeBetween(any(), any())).thenReturn(Collections.emptyList());
        when(workScheduleRepository.findByWorkDateBetween(any(), any())).thenReturn(Collections.emptyList());

        mockMvc.perform(get("/api/attendance/monthly")
                .param("year", "2026")
                .param("month", "6"))
                .andExpect(status().isOk());
    }

    @Test
    @WithUserDetails(value = "testemployee", setupBefore = TestExecutionEvent.TEST_EXECUTION)
    void getEmployeeLogsForSelfSucceeds() throws Exception {
        when(attendanceRecordRepository.findByEmployeeIdAndCheckTimeBetween(any(), any(), any()))
                .thenReturn(Collections.emptyList());
        when(workScheduleRepository.findByEmployeeAndDateRange(any(), any(), any()))
                .thenReturn(Collections.emptyList());

        mockMvc.perform(get("/api/attendance/" + employeeId + "/logs")
                .param("year", "2026")
                .param("month", "6"))
                .andExpect(status().isOk());
    }

    @Test
    @WithUserDetails(value = "testemployee", setupBefore = TestExecutionEvent.TEST_EXECUTION)
    void getEmployeeLogsForTechnicianSelfSucceeds() throws Exception {
        UserEntity technician = new UserEntity();
        technician.setId(employeeId);
        technician.setUsername("testemployee");
        technician.setRole(UserRole.TECHNICIAN);
        technician.setStatus(UserStatus.ACTIVE);

        when(userRepository.findByIdAndIsDeletedFalse(employeeId)).thenReturn(Optional.of(technician));
        when(attendanceRecordRepository.findByEmployeeIdAndCheckTimeBetween(any(), any(), any()))
                .thenReturn(Collections.emptyList());
        when(workScheduleRepository.findByEmployeeAndDateRange(any(), any(), any()))
                .thenReturn(Collections.emptyList());

        mockMvc.perform(get("/api/attendance/" + employeeId + "/logs")
                .param("year", "2026")
                .param("month", "6"))
                .andExpect(status().isOk());
    }

    @Test
    @WithUserDetails(value = "testemployee", setupBefore = TestExecutionEvent.TEST_EXECUTION)
    void getMyLogsAsEmployeeSucceeds() throws Exception {
        UserEntity employee = new UserEntity();
        employee.setId(employeeId);
        employee.setUsername("testemployee");
        employee.setRole(UserRole.EMPLOYEE);
        employee.setStatus(UserStatus.ACTIVE);

        when(userRepository.findByIdAndIsDeletedFalse(employeeId)).thenReturn(Optional.of(employee));
        when(attendanceRecordRepository.findByEmployeeIdAndCheckTimeBetween(any(), any(), any()))
                .thenReturn(Collections.emptyList());
        when(workScheduleRepository.findByEmployeeAndDateRange(any(), any(), any()))
                .thenReturn(Collections.emptyList());

        mockMvc.perform(get("/api/attendance/me/logs")
                .param("year", "2026")
                .param("month", "6"))
                .andExpect(status().isOk());
    }

    @Test
    @WithUserDetails(value = "testemployee", setupBefore = TestExecutionEvent.TEST_EXECUTION)
    void getEmployeeLogsForOtherAsEmployeeReturns403() throws Exception {
        UUID otherEmployeeId = UUID.randomUUID();
        mockMvc.perform(get("/api/attendance/" + otherEmployeeId + "/logs")
                .param("year", "2026")
                .param("month", "6"))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "MANAGER")
    void getEmployeeLogsForOtherAsManagerSucceeds() throws Exception {
        UserEntity employee = new UserEntity();
        employee.setId(employeeId);
        employee.setUsername("testemployee");
        employee.setRole(UserRole.EMPLOYEE);
        employee.setStatus(UserStatus.ACTIVE);

        when(userRepository.findByIdAndIsDeletedFalse(employeeId)).thenReturn(Optional.of(employee));
        when(attendanceRecordRepository.findByEmployeeIdAndCheckTimeBetween(any(), any(), any()))
                .thenReturn(Collections.emptyList());
        when(workScheduleRepository.findByEmployeeAndDateRange(any(), any(), any()))
                .thenReturn(Collections.emptyList());

        mockMvc.perform(get("/api/attendance/" + employeeId + "/logs")
                .param("year", "2026")
                .param("month", "6"))
                .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "MANAGER")
    void getMonthlyCalculatesLateAndOvertimeCorrectly() throws Exception {
        UUID empId = UUID.randomUUID();
        UserEntity employee = new UserEntity();
        employee.setId(empId);
        employee.setUsername("employee1");
        employee.setFullName("Employee One");
        employee.setEmployeeCode("EMP-001");
        employee.setRole(UserRole.EMPLOYEE);
        employee.setIsDeleted(false);

        when(userRepository.findAll()).thenReturn(java.util.List.of(employee));

        // 2026-06-01: IN at 08:30 (not late), OUT at 21:30 (overtime: past 21:00, 4.0 hrs OT from 17:30 to 21:30)
        java.time.Instant checkIn1 = java.time.LocalDateTime.of(2026, 6, 1, 8, 30).atZone(java.time.ZoneId.of("Asia/Ho_Chi_Minh")).toInstant();
        java.time.Instant checkOut1 = java.time.LocalDateTime.of(2026, 6, 1, 21, 30).atZone(java.time.ZoneId.of("Asia/Ho_Chi_Minh")).toInstant();

        AttendanceRecord recIn1 = AttendanceRecord.builder()
                .employeeId(empId)
                .type(AttendanceType.IN)
                .checkTime(checkIn1)
                .isValid(true)
                .build();
        recIn1.setIsDeleted(false);

        AttendanceRecord recOut1 = AttendanceRecord.builder()
                .employeeId(empId)
                .type(AttendanceType.OUT)
                .checkTime(checkOut1)
                .isValid(true)
                .build();
        recOut1.setIsDeleted(false);

        // 2026-06-02: IN at 08:50 (late because grace is 15 mins past 08:30), OUT at 18:00 (not overtime because checkout < 21:00)
        java.time.Instant checkIn2 = java.time.LocalDateTime.of(2026, 6, 2, 8, 50).atZone(java.time.ZoneId.of("Asia/Ho_Chi_Minh")).toInstant();
        java.time.Instant checkOut2 = java.time.LocalDateTime.of(2026, 6, 2, 18, 0).atZone(java.time.ZoneId.of("Asia/Ho_Chi_Minh")).toInstant();

        AttendanceRecord recIn2 = AttendanceRecord.builder()
                .employeeId(empId)
                .type(AttendanceType.IN)
                .checkTime(checkIn2)
                .isValid(true)
                .build();
        recIn2.setIsDeleted(false);

        AttendanceRecord recOut2 = AttendanceRecord.builder()
                .employeeId(empId)
                .type(AttendanceType.OUT)
                .checkTime(checkOut2)
                .isValid(true)
                .build();
        recOut2.setIsDeleted(false);

        // 2026-06-03: IN at 08:30, OUT at 12:00 -> Morning half-day (0.5 cong)
        java.time.Instant checkIn3 = java.time.LocalDateTime.of(2026, 6, 3, 8, 30).atZone(java.time.ZoneId.of("Asia/Ho_Chi_Minh")).toInstant();
        java.time.Instant checkOut3 = java.time.LocalDateTime.of(2026, 6, 3, 12, 0).atZone(java.time.ZoneId.of("Asia/Ho_Chi_Minh")).toInstant();

        AttendanceRecord recIn3 = AttendanceRecord.builder()
                .employeeId(empId)
                .type(AttendanceType.IN)
                .checkTime(checkIn3)
                .isValid(true)
                .build();
        recIn3.setIsDeleted(false);

        AttendanceRecord recOut3 = AttendanceRecord.builder()
                .employeeId(empId)
                .type(AttendanceType.OUT)
                .checkTime(checkOut3)
                .isValid(true)
                .build();
        recOut3.setIsDeleted(false);

        // 2026-06-04: IN at 13:30, OUT at 17:30 -> Afternoon half-day (0.5 cong)
        java.time.Instant checkIn4 = java.time.LocalDateTime.of(2026, 6, 4, 13, 30).atZone(java.time.ZoneId.of("Asia/Ho_Chi_Minh")).toInstant();
        java.time.Instant checkOut4 = java.time.LocalDateTime.of(2026, 6, 4, 17, 30).atZone(java.time.ZoneId.of("Asia/Ho_Chi_Minh")).toInstant();

        AttendanceRecord recIn4 = AttendanceRecord.builder()
                .employeeId(empId)
                .type(AttendanceType.IN)
                .checkTime(checkIn4)
                .isValid(true)
                .build();
        recIn4.setIsDeleted(false);

        AttendanceRecord recOut4 = AttendanceRecord.builder()
                .employeeId(empId)
                .type(AttendanceType.OUT)
                .checkTime(checkOut4)
                .isValid(true)
                .build();
        recOut4.setIsDeleted(false);

        // 2026-06-05: Afternoon + evening -> 1.0 day, without overtime.
        java.time.Instant checkIn5 = java.time.LocalDateTime.of(2026, 6, 5, 13, 30).atZone(java.time.ZoneId.of("Asia/Ho_Chi_Minh")).toInstant();
        java.time.Instant checkOut5 = java.time.LocalDateTime.of(2026, 6, 5, 21, 0).atZone(java.time.ZoneId.of("Asia/Ho_Chi_Minh")).toInstant();

        AttendanceRecord recIn5 = AttendanceRecord.builder()
                .employeeId(empId)
                .type(AttendanceType.IN)
                .checkTime(checkIn5)
                .isValid(true)
                .build();
        recIn5.setIsDeleted(false);

        AttendanceRecord recOut5 = AttendanceRecord.builder()
                .employeeId(empId)
                .type(AttendanceType.OUT)
                .checkTime(checkOut5)
                .isValid(true)
                .build();
        recOut5.setIsDeleted(false);

        when(attendanceRecordRepository.findByCheckTimeBetween(any(), any()))
                .thenReturn(java.util.List.of(recIn1, recOut1, recIn2, recOut2, recIn3, recOut3, recIn4, recOut4, recIn5, recOut5));
        when(workScheduleRepository.findByWorkDateBetween(any(), any()))
                .thenReturn(Collections.emptyList());

        mockMvc.perform(get("/api/attendance/monthly")
                .param("year", "2026")
                .param("month", "6"))
                .andExpect(status().isOk())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.data.employees[0].lateCount").value(1))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.data.employees[0].overtimeHours").value(4.0))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.data.employees[0].workDays").value(4.5))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.data.employees[0].absentDays").value(21))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.data.employees[0].leavedays").value(0));
    }

    @Test
    @WithMockUser(roles = "MANAGER")
    void getMonthlyReturnsUpdateNotesAndReasons() throws Exception {
        UUID empId = UUID.randomUUID();
        UserEntity employee = new UserEntity();
        employee.setId(empId);
        employee.setUsername("employee2");
        employee.setFullName("Nguyen Van A");
        employee.setEmployeeCode("EMP-002");
        employee.setRole(UserRole.EMPLOYEE);
        employee.setIsDeleted(false);

        when(userRepository.findAll()).thenReturn(java.util.List.of(employee));

        // Create a manual attendance record with note on 2026-06-05
        java.time.Instant checkIn = java.time.LocalDateTime.of(2026, 6, 5, 8, 0).atZone(java.time.ZoneId.of("Asia/Ho_Chi_Minh")).toInstant();
        AttendanceRecord rec = AttendanceRecord.builder()
                .employeeId(empId)
                .type(AttendanceType.IN)
                .checkTime(checkIn)
                .note("Quên quẹt thẻ")
                .isValid(true)
                .build();
        rec.setIsDeleted(false);

        when(attendanceRecordRepository.findByCheckTimeBetween(any(), any()))
                .thenReturn(java.util.List.of(rec));
        when(workScheduleRepository.findByWorkDateBetween(any(), any()))
                .thenReturn(Collections.emptyList());

        mockMvc.perform(get("/api/attendance/monthly")
                .param("year", "2026")
                .param("month", "6"))
                .andExpect(status().isOk())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.data.employees[0].updateNotes.5").value("[Vào 08:00] Quên quẹt thẻ"))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.data.employees[0].notes").value("Ngày 05: [Vào 08:00] Quên quẹt thẻ"));
    }
}
