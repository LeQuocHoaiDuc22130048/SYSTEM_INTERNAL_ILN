package com.suachuabientan.system_internal.modules.customer.controller;

import com.suachuabientan.system_internal.common.util.JwtUtil;
import com.suachuabientan.system_internal.config.SecurityConfig;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerResponse;
import com.suachuabientan.system_internal.modules.customer.enums.CustomerType;
import com.suachuabientan.system_internal.modules.customer.service.CustomerService;
import com.suachuabientan.system_internal.security.filter.JwtAuthFilter;
import com.suachuabientan.system_internal.security.service.UserDetailsServiceImpl;
import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.Page;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;
import java.util.UUID;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(CustomerController.class)
@Import(SecurityConfig.class)
class CustomerControllerTest {
    @Autowired MockMvc mvc;
    @MockBean CustomerService service;
    @MockBean JwtAuthFilter jwtAuthFilter;
    @MockBean UserDetailsServiceImpl users;
    @MockBean JwtUtil jwtUtil;

    @BeforeEach void setup() throws Exception {
        doAnswer(invocation -> {
            ((FilterChain) invocation.getArgument(2)).doFilter(invocation.getArgument(0), invocation.getArgument(1));
            return null;
        }).when(jwtAuthFilter).doFilter(any(), any(), any());
    }

    @Test void anonymousCannotListCustomers() throws Exception {
        mvc.perform(get("/api/v1/customers")).andExpect(status().isForbidden());
        verifyNoInteractions(service);
    }

    @Test @WithMockUser(roles = "TECHNICIAN") void roleAloneDoesNotGrantAccess() throws Exception {
        mvc.perform(get("/api/v1/customers")).andExpect(status().isForbidden());
    }

    @Test @WithMockUser(authorities = "CUSTOMER_VIEW") void viewerCanSearchButCannotCreate() throws Exception {
        when(service.getAll(any(), any(), any(), any())).thenReturn(Page.empty());
        mvc.perform(get("/api/v1/customers").param("keyword", "090").param("active", "true"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.content").isArray());
        mvc.perform(post("/api/v1/customers").contentType(MediaType.APPLICATION_JSON)
                .content("{\"customerName\":\"Khách A\",\"type\":\"INDIVIDUAL\"}"))
                .andExpect(status().isForbidden());
    }

    @Test @WithMockUser(authorities = "CUSTOMER_CREATE") void validCreateReturnsGeneratedIdentity() throws Exception {
        UUID id = UUID.randomUUID();
        when(service.create(any())).thenReturn(new CustomerResponse(id, "KH-A", "Khách A",
                CustomerType.INDIVIDUAL, null, null, null, null, null, true, null, null));
        mvc.perform(post("/api/v1/customers").contentType(MediaType.APPLICATION_JSON)
                .content("{\"customerName\":\"Khách A\",\"type\":\"INDIVIDUAL\"}"))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.data.id").value(id.toString()))
                .andExpect(jsonPath("$.data.active").value(true));
    }

    @Test @WithMockUser(authorities = "CUSTOMER_CREATE") void invalidFieldsAreRejectedBeforePersistence() throws Exception {
        mvc.perform(post("/api/v1/customers").contentType(MediaType.APPLICATION_JSON)
                .content("{\"customerName\":\"   \",\"email\":\"invalid\"}"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.errors").isArray());
        mvc.perform(patch("/api/v1/customers/" + UUID.randomUUID() + "/status")
                .contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(service);
    }

    @Test @WithMockUser(authorities = "CUSTOMER_VIEW") void viewerCannotUpdateOrDisableProfiles() throws Exception {
        String url = "/api/v1/customers/" + UUID.randomUUID();
        mvc.perform(put(url).contentType(MediaType.APPLICATION_JSON)
                .content("{\"customerName\":\"Khách A\",\"type\":\"COMPANY\"}"))
                .andExpect(status().isForbidden());
        mvc.perform(patch(url + "/status").contentType(MediaType.APPLICATION_JSON).content("{\"active\":false}"))
                .andExpect(status().isForbidden());
    }
}
