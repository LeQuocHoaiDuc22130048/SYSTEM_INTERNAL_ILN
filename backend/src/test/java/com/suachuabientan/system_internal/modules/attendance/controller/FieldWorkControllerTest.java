package com.suachuabientan.system_internal.modules.attendance.controller;

import com.suachuabientan.system_internal.common.util.JwtUtil;
import com.suachuabientan.system_internal.config.SecurityConfig;
import com.suachuabientan.system_internal.modules.attendance.dto.response.FieldWorkDayResponse;
import com.suachuabientan.system_internal.modules.attendance.service.FieldWorkService;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.enums.*;
import com.suachuabientan.system_internal.security.filter.JwtAuthFilter;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import com.suachuabientan.system_internal.security.service.UserDetailsServiceImpl;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.*;
import org.springframework.test.web.servlet.MockMvc;
import jakarta.servlet.FilterChain;
import java.time.LocalDate;
import java.util.UUID;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(FieldWorkController.class)
@Import(SecurityConfig.class)
class FieldWorkControllerTest {
    @Autowired private MockMvc mvc;
    @MockBean private FieldWorkService service;
    @MockBean private JwtAuthFilter jwtAuthFilter;
    @MockBean private UserDetailsServiceImpl users;
    @MockBean private JwtUtil jwtUtil;
    private UUID employeeId;

    @BeforeEach void setup() throws Exception {
        employeeId = UUID.randomUUID();
        doAnswer(i -> { ((FilterChain)i.getArgument(2)).doFilter(i.getArgument(0), i.getArgument(1)); return null; })
                .when(jwtAuthFilter).doFilter(any(), any(), any());
        UserEntity employee = new UserEntity();
        employee.setId(employeeId);
        employee.setUsername("employee");
        employee.setRole(UserRole.EMPLOYEE);
        employee.setStatus(UserStatus.ACTIVE);
        when(users.loadUserByUsername("employee")).thenReturn(new CustomUserDetails(employee));
    }

    @Test void unauthenticatedMutationIsRejected() throws Exception {
        mvc.perform(put("/api/attendance/me/field-work/2026-09-21")
                .contentType(MediaType.APPLICATION_JSON).content("{\"note\":\"ABC\"}"))
                .andExpect(status().isForbidden());
        verifyNoInteractions(service);
    }

    @Test @WithUserDetails(value = "employee", setupBefore = TestExecutionEvent.TEST_EXECUTION)
    void saveUsesPrincipalRatherThanSuppliedEmployeeId() throws Exception {
        LocalDate date = LocalDate.of(2026, 9, 21);
        when(service.save(employeeId, date, "ABC")).thenReturn(
                new FieldWorkDayResponse(UUID.randomUUID(), employeeId, date, "ABC", null, null));
        mvc.perform(put("/api/attendance/me/field-work/2026-09-21").contentType(MediaType.APPLICATION_JSON)
                .content("{\"note\":\"ABC\",\"employeeId\":\"" + UUID.randomUUID() + "\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.employeeId").value(employeeId.toString()));
        verify(service).save(employeeId, date, "ABC");
    }

    @Test @WithUserDetails(value = "employee", setupBefore = TestExecutionEvent.TEST_EXECUTION)
    void blankNoteIsRejectedBeforeSaving() throws Exception {
        mvc.perform(put("/api/attendance/me/field-work/2026-09-21").contentType(MediaType.APPLICATION_JSON)
                .content("{\"note\":\"  \"}"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(service);
    }

    @Test @WithUserDetails(value = "employee", setupBefore = TestExecutionEvent.TEST_EXECUTION)
    void deleteAndListUsePrincipal() throws Exception {
        mvc.perform(delete("/api/attendance/me/field-work/2026-09-21")).andExpect(status().isOk());
        verify(service).remove(employeeId, LocalDate.of(2026, 9, 21));
        mvc.perform(get("/api/attendance/me/field-work").param("from", "2026-09-01").param("to", "2026-09-30"))
                .andExpect(status().isOk());
        verify(service).list(employeeId, LocalDate.of(2026, 9, 1), LocalDate.of(2026, 9, 30));
    }
}
