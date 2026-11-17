package com.suachuabientan.system_internal.modules.quotation.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.quotation.dto.*;
import com.suachuabientan.system_internal.modules.quotation.enums.QuotationStatus;
import com.suachuabientan.system_internal.modules.quotation.service.RepairQuotationService;
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
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@Tag(name = "Repair Quotations", description = "Quản lý báo giá sửa chữa gom nhóm và đối soát chứng từ")
@RestController
@RequestMapping("/api/v1/repair-quotations")
@RequiredArgsConstructor
public class RepairQuotationController {

    private final RepairQuotationService quotationService;

    @Operation(summary = "Lấy các đơn sửa chữa của cùng khách hàng có thể gộp vào báo giá")
    @GetMapping("/pending-orders")
    @PreAuthorize("hasAuthority('REPAIR_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<List<PendingQuotationOrderResponse>>> getPendingOrdersForCustomer(
            @RequestParam UUID customerId) {
        return ResponseEntity.ok(ApiResponse.success(quotationService.getPendingOrdersForCustomer(customerId)));
    }

    @Operation(summary = "Tạo báo giá sửa chữa (1 hoặc nhiều máy của cùng khách hàng)")
    @PostMapping
    @PreAuthorize("hasAnyAuthority('REPAIR_QUOTATION_MANAGE', 'REPAIR_CUSTOMER_PUBLISH', 'REPAIR_UPDATE') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<QuotationResponse>> createQuotation(
            @Valid @RequestBody CreateQuotationRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.status(201)
                .body(ApiResponse.created(quotationService.createQuotation(request, userDetails.getUserId())));
    }

    @Operation(summary = "Danh sách báo giá sửa chữa")
    @GetMapping
    @PreAuthorize("hasAuthority('REPAIR_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<Page<QuotationResponse>>> searchQuotations(
            @RequestParam(required = false) UUID customerId,
            @RequestParam(required = false) QuotationStatus status,
            @RequestParam(required = false) UUID repairOrderId,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(
                quotationService.searchQuotations(customerId, status, repairOrderId, pageable)));
    }

    @Operation(summary = "Danh sách báo giá liên quan tới một đơn sửa chữa")
    @GetMapping("/by-order/{orderId}")
    @PreAuthorize("hasAuthority('REPAIR_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<List<QuotationResponse>>> getByOrderId(@PathVariable UUID orderId) {
        return ResponseEntity.ok(ApiResponse.success(quotationService.getQuotationsByOrderId(orderId)));
    }

    @Operation(summary = "Xem chi tiết một phiếu báo giá")
    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('REPAIR_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<QuotationResponse>> getById(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(quotationService.getQuotationById(id)));
    }

    @Operation(summary = "Gửi báo giá nháp cho khách hàng")
    @PostMapping("/{id}/send")
    @PreAuthorize("hasAnyAuthority('REPAIR_QUOTATION_MANAGE', 'REPAIR_CUSTOMER_PUBLISH', 'REPAIR_UPDATE') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<QuotationResponse>> sendQuotation(
            @PathVariable UUID id,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(quotationService.sendQuotation(id, userDetails.getUserId()),
                "Đã gửi báo giá tới khách hàng"));
    }

    @Operation(summary = "Hủy báo giá")
    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyAuthority('REPAIR_QUOTATION_MANAGE', 'REPAIR_CUSTOMER_PUBLISH', 'REPAIR_UPDATE') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<QuotationResponse>> cancelQuotation(
            @PathVariable UUID id,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(quotationService.cancelQuotation(id, userDetails.getUserId()),
                "Đã hủy báo giá"));
    }

    @Operation(summary = "Đối soát chứng từ thanh toán của khách hàng")
    @PostMapping("/payment-proofs/{proofId}/verify")
    @PreAuthorize("hasAnyAuthority('REPAIR_QUOTATION_MANAGE', 'REPAIR_CUSTOMER_PUBLISH', 'REPAIR_UPDATE') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<PaymentProofResponse>> verifyPaymentProof(
            @PathVariable UUID proofId,
            @Valid @RequestBody VerifyPaymentProofRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                quotationService.verifyPaymentProof(proofId, userDetails.getUserId(), request),
                request.approved() ? "Đã xác nhận thanh toán" : "Đã từ chối chứng từ"));
    }
}

