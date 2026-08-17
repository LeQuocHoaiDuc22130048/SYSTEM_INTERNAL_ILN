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

        // Let's create records for 2026-06-01:
        // IN at 08:15 (not late because grace is 15 mins), OUT at 18:30 (overtime starts past 18:00, so 0.5 hrs overtime)
        java.time.Instant checkIn1 = java.time.LocalDateTime.of(2026, 6, 1, 8, 15).atZone(java.time.ZoneId.of("Asia/Ho_Chi_Minh")).toInstant();
        java.time.Instant checkOut1 = java.time.LocalDateTime.of(2026, 6, 1, 18, 30).atZone(java.time.ZoneId.of("Asia/Ho_Chi_Minh")).toInstant();

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

        // Let's create records for 2026-06-02:
        // IN at 08:16 (late because grace is 15 mins, so > 8:15 is late), OUT at 18:00 (not overtime because OT starts after 18:00)
        java.time.Instant checkIn2 = java.time.LocalDateTime.of(2026, 6, 2, 8, 16).atZone(java.time.ZoneId.of("Asia/Ho_Chi_Minh")).toInstant();
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

        when(attendanceRecordRepository.findByCheckTimeBetween(any(), any()))
                .thenReturn(java.util.List.of(recIn1, recOut1, recIn2, recOut2));
        when(workScheduleRepository.findByWorkDateBetween(any(), any()))
                .thenReturn(Collections.emptyList());

        mockMvc.perform(get("/api/attendance/monthly")
                .param("year", "2026")
                .param("month", "6"))
                .andExpect(status().isOk())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.data.employees[0].lateCount").value(1))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.data.employees[0].overtimeHours").value(0.5));
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
