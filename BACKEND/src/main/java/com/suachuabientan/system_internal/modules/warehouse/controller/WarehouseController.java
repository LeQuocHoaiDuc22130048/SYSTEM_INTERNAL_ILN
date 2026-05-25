package com.suachuabientan.system_internal.modules.warehouse.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.CheckoutRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.CreateBoardItemRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.UpdateBoardItemRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.BoardItemResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.CheckoutResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.QrScanResponse;
import com.suachuabientan.system_internal.modules.warehouse.enums.BoardStatus;
import com.suachuabientan.system_internal.modules.warehouse.service.WarehouseService;
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
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@Tag(name = "Warehouse", description = "Quản lý kho bo mạch")
@RestController
@RequestMapping("/api/v1/boards")
@RequiredArgsConstructor
public class WarehouseController {
    private final WarehouseService warehouseService;

    @Operation(summary = "Tạo bo mạch mới")
    @PostMapping
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'EMPLOYEE')")
    public ResponseEntity<ApiResponse<BoardItemResponse>> create(
            @Valid @RequestBody CreateBoardItemRequest request,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        UUID userId = extractUserId(userDetails);
        return ResponseEntity.status(201)
                .body(ApiResponse.created(warehouseService.create(request, userId)));
    }

    @Operation(summary = "Danh sách bo mạch — có filter và search")
    @GetMapping
    public ResponseEntity<ApiResponse<Page<BoardItemResponse>>> getAll(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) BoardStatus status,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(
                warehouseService.getAll(keyword, status, pageable)));
    }

    @Operation(summary = "Chi tiết bo mạch")
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<BoardItemResponse>> getById(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(warehouseService.getById(id)));
    }

    @Operation(summary = "Cập nhật thông tin bo mạch")
    @PatchMapping("/{id}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'EMPLOYEE')")
    public ResponseEntity<ApiResponse<BoardItemResponse>> update(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateBoardItemRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = extractUserId(userDetails);
        return ResponseEntity.ok(ApiResponse.success(warehouseService.update(id, request, userId)));
    }

    @Operation(summary = "Xoá bo mạch (soft delete)")
    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<ApiResponse<Void>> delete(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {
        warehouseService.delete(id, extractUserId(userDetails));
        return ResponseEntity.ok(ApiResponse.success(null, "Xoá bo mạch thành công"));
    }

    // ── QR Scan ───────────────────────────────────────────────
    @Operation(summary = "Quét mã QR — trả thông tin bo mạch + người đang giữ")
    @GetMapping("/scan/{qrCode}")
    public ResponseEntity<ApiResponse<QrScanResponse>> scanQr(@PathVariable String qrCode) {
        return ResponseEntity.ok(ApiResponse.success(warehouseService.scanQr(qrCode)));
    }

    // ── Checkout / Return ─────────────────────────────────────
    @Operation(summary = "Lấy bo mạch để sửa chữa")
    @PostMapping("/{id}/checkout")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'EMPLOYEE')")
    public ResponseEntity<ApiResponse<CheckoutResponse>> checkout(
            @PathVariable UUID id,
            @RequestBody(required = false) CheckoutRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = extractUserId(userDetails);
        CheckoutRequest req = request != null ? request : new CheckoutRequest(null, null);
        return ResponseEntity.ok(ApiResponse.success(
                warehouseService.checkout(id, req, userId),
                "Lấy bo mạch thành công"));
    }

    @Operation(summary = "Trả bo mạch về kho")
    @PatchMapping("/{id}/return")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'EMPLOYEE')")
    public ResponseEntity<ApiResponse<CheckoutResponse>> returnBoard(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = extractUserId(userDetails);
        boolean isManager = ((CustomUserDetails) userDetails).isManagerOrAbove();
        return ResponseEntity.ok(ApiResponse.success(
                warehouseService.returnBoard(id, userId, isManager),
                "Trả bo mạch thành công"));
    }

    // ── History ───────────────────────────────────────────────
    @Operation(summary = "Lịch sử lấy/trả của bo mạch")
    @GetMapping("/{id}/history")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'WAREHOUSE_STAFF')")
    public ResponseEntity<ApiResponse<Page<CheckoutResponse>>> getHistory(
            @PathVariable UUID id,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(warehouseService.getHistory(id, pageable)));
    }

    private UUID extractUserId(UserDetails userDetails) {
        return ((CustomUserDetails) userDetails).getUserId();
    }
}

