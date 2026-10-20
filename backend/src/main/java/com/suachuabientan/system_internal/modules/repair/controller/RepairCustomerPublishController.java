package com.suachuabientan.system_internal.modules.repair.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerMediaResponse;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerUpdateResponse;
import com.suachuabientan.system_internal.modules.customer.service.CustomerPortalService;
import com.suachuabientan.system_internal.modules.repair.dto.request.PublishCustomerMediaRequest;
import com.suachuabientan.system_internal.modules.repair.dto.request.PublishCustomerUpdateRequest;
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

@Tag(name = "Repair Customer Publishing", description = "Công bố thông tin và hình ảnh cho khách hàng")
@RestController
@RequestMapping("/api/v1/repair-orders/{orderId}")
@RequiredArgsConstructor
public class RepairCustomerPublishController {

    private final CustomerPortalService portalService;

    @Operation(summary = "Đăng cập nhật tiến độ công khai cho khách hàng")
    @PostMapping("/customer-updates")
    @PreAuthorize("hasAuthority('REPAIR_CUSTOMER_PUBLISH') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<CustomerUpdateResponse>> publishUpdate(
            @PathVariable UUID orderId,
            @Valid @RequestBody PublishCustomerUpdateRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.status(201).body(ApiResponse.created(
                portalService.publishCustomerUpdate(orderId, request, userDetails.getUserId())
        ));
    }

    @Operation(summary = "Xem danh sách cập nhật tiến độ công khai của đơn")
    @GetMapping("/customer-updates")
    @PreAuthorize("hasAuthority('REPAIR_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<List<CustomerUpdateResponse>>> getUpdates(
            @PathVariable UUID orderId) {
        return ResponseEntity.ok(ApiResponse.success(portalService.getPublishedUpdates(orderId)));
    }

    @Operation(summary = "Công bố hình ảnh nghiệm thu cho khách hàng xem")
    @PostMapping("/customer-media")
    @PreAuthorize("hasAuthority('REPAIR_CUSTOMER_PUBLISH') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<CustomerMediaResponse>> publishMedia(
            @PathVariable UUID orderId,
            @Valid @RequestBody PublishCustomerMediaRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.status(201).body(ApiResponse.created(
                portalService.publishCustomerMedia(orderId, request, userDetails.getUserId())
        ));
    }

    @Operation(summary = "Xem danh sách hình ảnh đã công bố cho khách hàng")
    @GetMapping("/customer-media")
    @PreAuthorize("hasAuthority('REPAIR_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<List<CustomerMediaResponse>>> getMedia(
            @PathVariable UUID orderId) {
        return ResponseEntity.ok(ApiResponse.success(portalService.getPublishedMedia(orderId)));
    }
}
