package com.suachuabientan.system_internal.modules.customer.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.auth.dto.request.ChangePasswordRequest;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerOrderDetailResponse;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerOrderResponse;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerResponse;
import com.suachuabientan.system_internal.modules.customer.service.CustomerPortalService;
import com.suachuabientan.system_internal.modules.customer.service.PortalSupportConfigService;
import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerAccountProfileResponse;
import com.suachuabientan.system_internal.modules.customer.dto.UpdateCustomerAccountProfileRequest;
import org.springframework.http.MediaType;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@Tag(name = "Customer Portal", description = "Các API dành riêng cho khách hàng theo dõi đơn hàng")
@RestController
@RequestMapping("/api/v1/customer")
@RequiredArgsConstructor
public class CustomerPortalController {

    private final CustomerPortalService portalService;

    @Operation(summary = "Lấy thông tin tài khoản và avatar của khách hàng hiện tại")
    @GetMapping("/account-profile")
    @PreAuthorize("hasAuthority('CUSTOMER_PORTAL_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<CustomerAccountProfileResponse>> getAccountProfile(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(portalService.getAccountProfile(userDetails.getUserId())));
    }

    @Operation(summary = "Cập nhật thông tin cá nhân của tài khoản khách hàng")
    @PutMapping("/account-profile")
    @PreAuthorize("hasAuthority('CUSTOMER_PORTAL_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<CustomerAccountProfileResponse>> updateAccountProfile(
            @Valid @RequestBody UpdateCustomerAccountProfileRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                portalService.updateAccountProfile(userDetails.getUserId(), request),
                "Cập nhật thông tin thành công"
        ));
    }

    @Operation(summary = "Cập nhật ảnh đại diện (avatar) của khách hàng")
    @PostMapping(value = "/avatar", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAuthority('CUSTOMER_PORTAL_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<CustomerAccountProfileResponse>> updateAvatar(
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                portalService.updateAvatar(userDetails.getUserId(), file),
                "Cập nhật ảnh đại diện thành công"
        ));
    }

    @Operation(summary = "Lấy thông tin hồ sơ của khách hàng hiện tại")
    @GetMapping("/me")
    @PreAuthorize("hasAuthority('CUSTOMER_PORTAL_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<CustomerResponse>> getMyProfile(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(portalService.getMyProfile(userDetails.getUserId())));
    }

    @Operation(summary = "Lấy danh sách các đơn sửa chữa của khách hàng")
    @GetMapping("/orders")
    @PreAuthorize("hasAuthority('CUSTOMER_PORTAL_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<Page<CustomerOrderResponse>>> getMyOrders(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) RepairStatus status,
            @PageableDefault(size = 20) Pageable pageable,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                portalService.getMyOrders(userDetails.getUserId(), keyword, status, pageable)
        ));
    }

    @Operation(summary = "Xem chi tiết một đơn sửa chữa của khách hàng")
    @GetMapping("/orders/{orderId}")
    @PreAuthorize("hasAuthority('CUSTOMER_PORTAL_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<CustomerOrderDetailResponse>> getMyOrderDetail(
            @PathVariable UUID orderId,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                portalService.getMyOrderDetail(userDetails.getUserId(), orderId)
        ));
    }

    private final PortalSupportConfigService supportConfigService;

    @Operation(summary = "Xem thông tin kênh hỗ trợ kỹ thuật (Hotline, Zalo)")
    @GetMapping("/support-info")
    @PreAuthorize("hasAuthority('CUSTOMER_PORTAL_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<com.suachuabientan.system_internal.modules.customer.dto.PortalSupportConfigResponse>> getSupportInfo() {
        return ResponseEntity.ok(ApiResponse.success(supportConfigService.getSupportConfig()));
    }

    @Operation(summary = "Khách hàng đổi mật khẩu tài khoản của mình")
    @PostMapping("/change-password")
    @PreAuthorize("hasAuthority('CUSTOMER_PORTAL_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<Void>> changePassword(
            @Valid @RequestBody ChangePasswordRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        portalService.changePassword(userDetails.getUserId(), request);
        return ResponseEntity.ok(ApiResponse.success(null, "Đổi mật khẩu thành công"));
    }
}

