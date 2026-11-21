package com.suachuabientan.system_internal.modules.quotation.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.quotation.dto.PaymentProofResponse;
import com.suachuabientan.system_internal.modules.quotation.dto.QuotationResponse;
import com.suachuabientan.system_internal.modules.quotation.dto.RespondQuotationRequest;
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
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.math.BigDecimal;
import java.util.UUID;

@Tag(name = "Customer Portal Quotations", description = "Khách hàng xem, duyệt báo giá từng máy và gửi chứng từ thanh toán")
@RestController
@RequestMapping("/api/v1/customer/quotations")
@RequiredArgsConstructor
public class CustomerQuotationController {

    private final RepairQuotationService quotationService;

    @Operation(summary = "Danh sách báo giá của khách hàng hiện tại")
    @GetMapping
    @PreAuthorize("hasAuthority('CUSTOMER_PORTAL_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<Page<QuotationResponse>>> getMyQuotations(
            @RequestParam(required = false) QuotationStatus status,
            @PageableDefault(size = 20) Pageable pageable,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                quotationService.getMyQuotations(userDetails.getUserId(), status, pageable)));
    }

    @Operation(summary = "Xem chi tiết một phiếu báo giá của khách hàng")
    @GetMapping("/{quotationId}")
    @PreAuthorize("hasAuthority('CUSTOMER_PORTAL_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<QuotationResponse>> getMyQuotationDetail(
            @PathVariable UUID quotationId,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                quotationService.getMyQuotationDetail(userDetails.getUserId(), quotationId)));
    }

    @Operation(summary = "Khách hàng xác nhận duyệt / từ chối từng máy trong báo giá")
    @PostMapping("/{quotationId}/respond")
    @PreAuthorize("hasAuthority('CUSTOMER_PORTAL_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<QuotationResponse>> respondToQuotation(
            @PathVariable UUID quotationId,
            @Valid @RequestBody RespondQuotationRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                quotationService.respondToQuotation(quotationId, userDetails.getUserId(), request),
                "Đã ghi nhận xác nhận phương án sửa chữa"));
    }

    @Operation(summary = "Khách hàng tải lên ảnh/PDF chứng từ thanh toán")
    @PostMapping(value = "/{quotationId}/payment-proofs", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAuthority('CUSTOMER_PORTAL_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<PaymentProofResponse>> submitPaymentProof(
            @PathVariable UUID quotationId,
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "amount", required = false) BigDecimal amount,
            @RequestParam(value = "note", required = false) String note,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.status(201).body(ApiResponse.created(
                quotationService.submitPaymentProof(quotationId, userDetails.getUserId(), file, amount, note)));
    }
}

