package com.suachuabientan.system_internal.security;

import com.suachuabientan.system_internal.common.util.JwtUtil;
import com.suachuabientan.system_internal.config.SecurityConfig;
import com.suachuabientan.system_internal.modules.repair.controller.RepairController;
import com.suachuabientan.system_internal.modules.repair.service.RepairService;
import com.suachuabientan.system_internal.modules.warehouse.controller.WarehouseController;
import com.suachuabientan.system_internal.modules.warehouse.service.WarehouseService;
import com.suachuabientan.system_internal.modules.employee.controller.EmployeeController;
import com.suachuabientan.system_internal.modules.employee.service.EmployeeService;
import com.suachuabientan.system_internal.modules.notification.controller.NotificationController;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import com.suachuabientan.system_internal.security.filter.JwtAuthFilter;
import com.suachuabientan.system_internal.security.service.UserDetailsServiceImpl;
import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest({WarehouseController.class, RepairController.class, EmployeeController.class, NotificationController.class})
@Import(SecurityConfig.class)
class PermissionEnforcementTest {
    @Test void creatingAnOrderDoesNotGrantPermissionToEditIt() throws Exception {
        var account = new com.suachuabientan.system_internal.modules.auth.entity.UserEntity();
        account.setId(java.util.UUID.randomUUID()); account.setUsername("creator");
        account.setRole(com.suachuabientan.system_internal.modules.auth.enums.UserRole.EMPLOYEE);
        account.setStatus(com.suachuabientan.system_internal.modules.auth.enums.UserStatus.ACTIVE);
        var principal = new com.suachuabientan.system_internal.security.model.CustomUserDetails(account,
                java.util.Set.of(), java.util.Set.of("REPAIR_CREATE"));
        String body = "{\"customerName\":\"Khach A\",\"devices\":[{\"deviceName\":\"May\"}]}";
        mvc.perform(post("/api/v1/repair-orders").with(user(principal))
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isCreated());
        mvc.perform(put("/api/v1/repair-orders/" + java.util.UUID.randomUUID()).with(user(principal))
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isForbidden());
        mvc.perform(post("/api/v1/repair-orders").with(user(principal))
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                .content("{\"customerName\":\"Khach A\",\"devices\":[{\"deviceName\":\"May\",\"assignedToId\":\"" + java.util.UUID.randomUUID() + "\"}]}"))
                .andExpect(status().isForbidden());
    }
    @Autowired MockMvc mvc;
    @Test @WithMockUser(authorities = "REPAIR_STATUS_UPDATE") void statusPermissionCannotCancelAnOrder() throws Exception {
        mvc.perform(patch("/api/v1/repair-orders/" + java.util.UUID.randomUUID() + "/status")
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON).content("{\"status\":\"CANCELLED\"}"))
                .andExpect(status().isForbidden());
    }
    @MockBean WarehouseService warehouse;
    @MockBean RepairService repair;
    @MockBean EmployeeService employees;
    @MockBean NotificationService notifications;
    @MockBean JwtAuthFilter jwt;
    @MockBean UserDetailsServiceImpl users;
    @MockBean JwtUtil tokens;

    @BeforeEach void setup() throws Exception {
        doAnswer(i -> { ((FilterChain) i.getArgument(2)).doFilter(i.getArgument(0), i.getArgument(1)); return null; })
                .when(jwt).doFilter(any(), any(), any());
    }

    @Test @WithMockUser(roles = "ADMIN") void normalAdminRoleDoesNotBypassRevokedViewPermission() throws Exception {
        mvc.perform(get("/api/v1/boards")).andExpect(status().isForbidden());
        verifyNoInteractions(warehouse);
    }

    @Test void explicitGrantLetsEmployeeReadWarehouse() throws Exception {
        mvc.perform(get("/api/v1/boards").with(user("employee").authorities(new SimpleGrantedAuthority("ROLE_EMPLOYEE"), new SimpleGrantedAuthority("WAREHOUSE_VIEW"))))
                .andExpect(status().isOk());
    }

    @Test void managePermissionDoesNotImplyDelete() throws Exception {
        mvc.perform(delete("/api/v1/boards/" + java.util.UUID.randomUUID()).with(user("employee").authorities(new SimpleGrantedAuthority("BOARD_UPDATE"))))
                .andExpect(status().isForbidden());
        verifyNoInteractions(warehouse);
    }

    @Test @WithMockUser(roles = "MANAGER") void repairListRequiresViewPermissionEvenForManager() throws Exception {
        mvc.perform(get("/api/v1/repair-orders")).andExpect(status().isForbidden());
        verifyNoInteractions(repair);
    }

    @Test @WithMockUser(roles = "SUPER_ADMIN") void superAdminKeepsEmergencyAccess() throws Exception {
        mvc.perform(get("/api/v1/boards")).andExpect(status().isOk());
    }

    @Test void assignmentGrantProvidesAssigneeDirectoryWithoutEmployeeManagement() throws Exception {
        mvc.perform(get("/api/v1/employees/repair-assignees").with(user("technician").authorities(new SimpleGrantedAuthority("REPAIR_ASSIGN"))))
                .andExpect(status().isOk());
        mvc.perform(get("/api/v1/employees").with(user("technician").authorities(new SimpleGrantedAuthority("REPAIR_ASSIGN"))))
                .andExpect(status().isForbidden());
    }

    @Test @WithMockUser(roles = "TECHNICIAN") void roleAloneCannotUpdateStatusAfterRevocation() throws Exception {
        mvc.perform(patch("/api/v1/repair-orders/" + java.util.UUID.randomUUID() + "/status")
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON).content("{\"status\":\"CHECKING\"}"))
                .andExpect(status().isForbidden());
    }

    @Test void selfDeviceRegistrationDoesNotGrantNotificationReadAccess() throws Exception {
        var account = new com.suachuabientan.system_internal.modules.auth.entity.UserEntity();
        account.setId(java.util.UUID.randomUUID()); account.setUsername("employee");
        account.setRole(com.suachuabientan.system_internal.modules.auth.enums.UserRole.EMPLOYEE);
        account.setStatus(com.suachuabientan.system_internal.modules.auth.enums.UserStatus.ACTIVE);
        var principal = new com.suachuabientan.system_internal.security.model.CustomUserDetails(account);
        mvc.perform(put("/api/v1/notifications/device-token").with(user(principal))
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON).content("{\"deviceToken\":\"device-token\"}"))
                .andExpect(status().isOk());
        mvc.perform(get("/api/v1/notifications").with(user(principal))).andExpect(status().isForbidden());
    }
}
