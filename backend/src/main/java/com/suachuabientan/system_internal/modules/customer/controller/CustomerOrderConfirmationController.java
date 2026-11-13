package com.suachuabientan.system_internal.modules.customer.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerOrderConfirmRequest;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerOrderConfirmationResponse;
import com.suachuabientan.system_internal.modules.customer.service.CustomerOrderConfirmationService;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.UUID;

@Tag(name = "Customer Order Confirmation", description = "Báo giá, xác nhận đơn hàng và gửi chứng từ thanh toán cho khách hàng")
@RestController
@RequestMapping("/api/v1/customer/orders/{orderId}")
@RequiredArgsConstructor
public class CustomerOrderConfirmationController {

    private final CustomerOrderConfirmationService confirmationService;

    @Operation(summary = "Lấy thông tin báo giá và trạng thái xác nhận đơn hàng của khách hàng")
    @GetMapping("/confirmation")
    @PreAuthorize("hasAuthority('CUSTOMER_PORTAL_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<CustomerOrderConfirmationResponse>> getConfirmation(
            @PathVariable UUID orderId,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                confirmationService.getConfirmation(userDetails.getUserId(), orderId)
        ));
    }

    @Operation(summary = "Khách hàng duyệt hoặc từ chối báo giá đơn sửa chữa")
    @PostMapping("/confirm")
    @PreAuthorize("hasAuthority('CUSTOMER_PORTAL_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<CustomerOrderConfirmationResponse>> confirmQuote(
            @PathVariable UUID orderId,
            @Valid @RequestBody CustomerOrderConfirmRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                confirmationService.confirmQuote(userDetails.getUserId(), orderId, request),
                "Đã cập nhật xác nhận đơn hàng"
        ));
    }

    @Operation(summary = "Khách hàng tải lên ảnh chứng từ chuyển khoản thanh toán")
    @PostMapping(value = "/payment-proof", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAuthority('CUSTOMER_PORTAL_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<CustomerOrderConfirmationResponse>> uploadPaymentProof(
            @PathVariable UUID orderId,
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "warrantyMonths", required = false) Integer warrantyMonths,
            @RequestParam(value = "transferReference", required = false) String transferReference,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                confirmationService.uploadPaymentProof(
                        userDetails.getUserId(),
                        orderId,
                        file,
                        warrantyMonths,
                        transferReference
                ),
                "Đã gửi chứng từ thanh toán"
        ));
    }
}

