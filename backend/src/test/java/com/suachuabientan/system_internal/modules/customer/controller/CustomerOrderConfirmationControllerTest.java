package com.suachuabientan.system_internal.modules.customer.controller;

import com.suachuabientan.system_internal.common.util.JwtUtil;
import com.suachuabientan.system_internal.config.SecurityConfig;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.enums.UserStatus;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerOrderConfirmationResponse;
import com.suachuabientan.system_internal.modules.customer.service.CustomerOrderConfirmationService;
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
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import java.util.Set;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(CustomerOrderConfirmationController.class)
@Import(SecurityConfig.class)
class CustomerOrderConfirmationControllerTest {

    @Autowired
    private MockMvc mvc;

    @MockBean
    private CustomerOrderConfirmationService confirmationService;

    @MockBean
    private JwtAuthFilter jwtAuthFilter;

    @MockBean
    private UserDetailsServiceImpl userDetailsService;

    @MockBean
    private JwtUtil jwtUtil;

    private UUID userId;
    private UUID orderId;

    @BeforeEach
    void setup() throws Exception {
        userId = UUID.randomUUID();
        orderId = UUID.randomUUID();
        doAnswer(invocation -> {
            ((FilterChain) invocation.getArgument(2)).doFilter(invocation.getArgument(0), invocation.getArgument(1));
            return null;
        }).when(jwtAuthFilter).doFilter(any(), any(), any());
    }

    private CustomUserDetails customerUser() {
        UserEntity user = new UserEntity();
        user.setId(userId);
        user.setUsername("khach_vip");
        user.setRole(UserRole.CUSTOMER);
        user.setStatus(UserStatus.ACTIVE);
        return new CustomUserDetails(user, Set.of("CUSTOMER"), Set.of("CUSTOMER_PORTAL_VIEW"));
    }

    private CustomUserDetails technicianUser() {
        UserEntity user = new UserEntity();
        user.setId(UUID.randomUUID());
        user.setUsername("tech_01");
        user.setRole(UserRole.TECHNICIAN);
        user.setStatus(UserStatus.ACTIVE);
        return new CustomUserDetails(user, Set.of("TECHNICIAN"), Set.of("REPAIR_VIEW"));
    }

    private CustomerOrderConfirmationResponse sampleResponse(String status) {
        return new CustomerOrderConfirmationResponse(
                orderId,
                status,
                6,
                0L,
                4_850_000L,
                4_850_000L,
                List.of("Hỏng công suất vào/ra"),
                List.of(),
                "MB Bank (Quân Đội)",
                "MB",
                "9964266771",
                "CONG TY TNHH KY THUAT CONG NGHE",
                "RO-20261106-005",
                null,
                null,
                null,
                null,
                null,
                null
        );
    }

    @Test
    void anonymousOrNonCustomerCannotAccessConfirmationEndpoints() throws Exception {
        mvc.perform(get("/api/v1/customer/orders/{id}/confirmation", orderId))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/customer/orders/{id}/confirmation", orderId).with(user(technicianUser())))
                .andExpect(status().isForbidden());
        verifyNoInteractions(confirmationService);
    }

    @Test
    void customerCanFetchConfirmAndUploadProof() throws Exception {
        when(confirmationService.getConfirmation(userId, orderId))
                .thenReturn(sampleResponse("PENDING_CUSTOMER"));
        when(confirmationService.confirmQuote(eq(userId), eq(orderId), any()))
                .thenReturn(sampleResponse("APPROVED"));
        when(confirmationService.uploadPaymentProof(eq(userId), eq(orderId), any(), any(), any()))
                .thenReturn(sampleResponse("PAYMENT_SUBMITTED"));

        mvc.perform(get("/api/v1/customer/orders/{id}/confirmation", orderId).with(user(customerUser())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.confirmationStatus").value("PENDING_CUSTOMER"))
                .andExpect(jsonPath("$.data.accountNumber").value("9964266771"));

        mvc.perform(post("/api/v1/customer/orders/{id}/confirm", orderId)
                        .with(user(customerUser()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"action\":\"APPROVE\",\"warrantyMonths\":6}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.confirmationStatus").value("APPROVED"));

        MockMultipartFile file = new MockMultipartFile("file", "proof.jpg", "image/jpeg", new byte[]{1, 2, 3});
        mvc.perform(multipart("/api/v1/customer/orders/{id}/payment-proof", orderId)
                        .file(file)
                        .param("warrantyMonths", "6")
                        .with(user(customerUser())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.confirmationStatus").value("PAYMENT_SUBMITTED"));
    }
}

