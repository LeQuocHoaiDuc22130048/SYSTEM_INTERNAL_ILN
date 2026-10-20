package com.suachuabientan.system_internal.modules.customer.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.customer.dto.CreateCustomerAccountRequest;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerAccountCreatedResponse;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerAccountResponse;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerStatusRequest;
import com.suachuabientan.system_internal.modules.customer.dto.ResetCustomerPasswordRequest;
import com.suachuabientan.system_internal.modules.customer.service.CustomerAccountService;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@Tag(name = "Customer Accounts", description = "Quản lý tài khoản đăng nhập của khách hàng")
@RestController
@RequestMapping("/api/v1/customers/{customerId}/accounts")
@RequiredArgsConstructor
public class CustomerAccountController {

    private final CustomerAccountService accountService;

    @Operation(summary = "Tạo tài khoản đăng nhập trực tiếp cho khách hàng")
    @PostMapping
    @PreAuthorize("hasAuthority('CUSTOMER_ACCOUNT_MANAGE') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<CustomerAccountCreatedResponse>> createAccount(
            @PathVariable UUID customerId,
            @Valid @RequestBody CreateCustomerAccountRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.status(201).body(ApiResponse.created(
                accountService.createAccount(customerId, request, userDetails.getUserId())
        ));
    }

    @Operation(summary = "Danh sách tài khoản của khách hàng")
    @GetMapping
    @PreAuthorize("hasAuthority('CUSTOMER_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<List<CustomerAccountResponse>>> getAccounts(
            @PathVariable UUID customerId) {
        return ResponseEntity.ok(ApiResponse.success(accountService.getAccounts(customerId)));
    }

    @Operation(summary = "Reset mật khẩu tài khoản khách hàng")
    @PostMapping("/{accountId}/reset-password")
    @PreAuthorize("hasAuthority('CUSTOMER_ACCOUNT_MANAGE') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<CustomerAccountResponse>> resetPassword(
            @PathVariable UUID customerId,
            @PathVariable UUID accountId,
            @Valid @RequestBody ResetCustomerPasswordRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                accountService.resetPassword(customerId, accountId, request, userDetails.getUserId())
        ));
    }

    @Operation(summary = "Khóa hoặc mở lại tài khoản khách hàng")
    @PatchMapping("/{accountId}/status")
    @PreAuthorize("hasAuthority('CUSTOMER_ACCOUNT_MANAGE') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<CustomerAccountResponse>> setStatus(
            @PathVariable UUID customerId,
            @PathVariable UUID accountId,
            @Valid @RequestBody CustomerStatusRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                accountService.setStatus(customerId, accountId, request.active(), userDetails.getUserId())
        ));
    }
}
