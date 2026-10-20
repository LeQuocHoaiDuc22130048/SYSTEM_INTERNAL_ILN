package com.suachuabientan.system_internal.security;

import com.suachuabientan.system_internal.common.util.JwtUtil;
import com.suachuabientan.system_internal.config.SecurityConfig;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.enums.UserStatus;
import com.suachuabientan.system_internal.modules.customer.controller.CustomerPortalController;
import com.suachuabientan.system_internal.modules.customer.controller.PortalPublicController;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerOrderDetailResponse;
import com.suachuabientan.system_internal.modules.customer.dto.PortalTrackRequest;
import com.suachuabientan.system_internal.modules.customer.service.CustomerPortalService;
import com.suachuabientan.system_internal.modules.repair.controller.RepairController;
import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import com.suachuabientan.system_internal.modules.repair.service.RepairService;
import com.suachuabientan.system_internal.modules.warehouse.controller.WarehouseController;
import com.suachuabientan.system_internal.modules.warehouse.service.WarehouseService;
import com.suachuabientan.system_internal.security.filter.JwtAuthFilter;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import com.suachuabientan.system_internal.security.service.UserDetailsServiceImpl;
import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.PageImpl;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest({CustomerPortalController.class, PortalPublicController.class, RepairController.class, WarehouseController.class})
@Import(SecurityConfig.class)
class CustomerPortalSecurityTest {

    @Autowired
    private MockMvc mvc;

    @MockBean
    private CustomerPortalService portalService;

    @MockBean
    private RepairService repairService;

    @MockBean
    private WarehouseService warehouseService;

    @MockBean
    private com.suachuabientan.system_internal.modules.customer.service.PortalSupportConfigService supportConfigService;

    @MockBean
    private JwtAuthFilter jwtAuthFilter;

    @MockBean
    private UserDetailsServiceImpl userDetailsService;

    @MockBean
    private JwtUtil jwtUtil;

    @BeforeEach
    void setup() throws Exception {
        doAnswer(i -> {
            ((FilterChain) i.getArgument(2)).doFilter(i.getArgument(0), i.getArgument(1));
            return null;
        }).when(jwtAuthFilter).doFilter(any(), any(), any());
    }

    private CustomUserDetails customerUser() {
        UserEntity user = new UserEntity();
        user.setId(UUID.randomUUID());
        user.setUsername("khach_vip");
        user.setRole(UserRole.CUSTOMER);
        user.setStatus(UserStatus.ACTIVE);
        return new CustomUserDetails(user, Set.of("CUSTOMER"), Set.of("CUSTOMER_PORTAL_VIEW"));
    }

    private CustomUserDetails employeeUser() {
        UserEntity user = new UserEntity();
        user.setId(UUID.randomUUID());
        user.setUsername("technician_1");
        user.setRole(UserRole.TECHNICIAN);
        user.setStatus(UserStatus.ACTIVE);
        return new CustomUserDetails(user, Set.of("TECHNICIAN"), Set.of("REPAIR_VIEW", "WAREHOUSE_VIEW"));
    }

    @Test
    void customerCannotAccessInternalRepairOrdersList() throws Exception {
        mvc.perform(get("/api/v1/repair-orders").with(user(customerUser())))
                .andExpect(status().isForbidden());
    }

    @Test
    void customerCannotAccessInternalWarehouse() throws Exception {
        mvc.perform(get("/api/v1/boards").with(user(customerUser())))
                .andExpect(status().isForbidden());
    }

    @Test
    void customerWithPortalPermissionCanAccessCustomerOrders() throws Exception {
        when(portalService.getMyOrders(any(), any(), any(), any()))
                .thenReturn(new PageImpl<>(List.of()));

        mvc.perform(get("/api/v1/customer/orders").with(user(customerUser())))
                .andExpect(status().isOk());
    }

    @Test
    void employeeWithoutCustomerPortalPermissionCannotAccessCustomerOrders() throws Exception {
        mvc.perform(get("/api/v1/customer/orders").with(user(employeeUser())))
                .andExpect(status().isForbidden());
    }

    @Test
    void publicUserCanAccessPortalTrackWithoutAuth() throws Exception {
        CustomerOrderDetailResponse detail = new CustomerOrderDetailResponse(
                UUID.randomUUID(), "RO-20261017-001", RepairStatus.PENDING, "Đã tiếp nhận",
                Instant.now(), null, null, null, "Khách A", "Lỗi nổ tụ",
                List.of(), List.of(), List.of()
        );
        when(portalService.trackOrder(any(PortalTrackRequest.class))).thenReturn(detail);

        String json = "{\"orderCode\":\"RO-20261017-001\",\"phone\":\"0987654321\"}";
        mvc.perform(post("/api/v1/portal/track")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
                .andExpect(status().isOk());
    }
}
