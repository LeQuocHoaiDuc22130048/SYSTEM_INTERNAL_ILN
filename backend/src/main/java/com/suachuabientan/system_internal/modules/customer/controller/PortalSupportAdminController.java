package com.suachuabientan.system_internal.modules.customer.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.customer.dto.PortalSupportConfigResponse;
import com.suachuabientan.system_internal.modules.customer.dto.UpdatePortalSupportConfigRequest;
import com.suachuabientan.system_internal.modules.customer.service.PortalSupportConfigService;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@Tag(name = "Portal Support Config Admin", description = "Quản lý kênh hỗ trợ Hotline & Zalo Cổng Khách Hàng")
@RestController
@RequestMapping("/api/v1/admin/portal-config")
@RequiredArgsConstructor
public class PortalSupportAdminController {

    private final PortalSupportConfigService service;

    @Operation(summary = "Lấy cấu hình kênh hỗ trợ Hotline, Zalo hiện tại")
    @GetMapping
    @PreAuthorize("hasAuthority('CUSTOMER_ACCOUNTS_MANAGE') or hasRole('ADMIN') or hasRole('MANAGER') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<PortalSupportConfigResponse>> getSupportConfig() {
        return ResponseEntity.ok(ApiResponse.success(service.getSupportConfig()));
    }

    @Operation(summary = "Cập nhật cấu hình kênh hỗ trợ Hotline, Zalo cho Cổng Khách Hàng")
    @PutMapping
    @PreAuthorize("hasAuthority('CUSTOMER_ACCOUNTS_MANAGE') or hasRole('ADMIN') or hasRole('MANAGER') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<PortalSupportConfigResponse>> updateSupportConfig(
            @Valid @RequestBody UpdatePortalSupportConfigRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                service.updateSupportConfig(request, userDetails != null ? userDetails.getUserId() : null)
        ));
    }
}
