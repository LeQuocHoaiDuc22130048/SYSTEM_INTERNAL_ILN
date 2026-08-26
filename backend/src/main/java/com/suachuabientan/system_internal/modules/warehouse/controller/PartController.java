package com.suachuabientan.system_internal.modules.warehouse.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.AdjustStockRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.BulkImportPartRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.CreatePartRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.CreateStoreLocationRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.UpdateStoreLocationRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.PartCheckoutRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.PartReturnRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.UpdatePartRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.BulkImportPartResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.CategoryInfo;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.LocationInfo;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.LocationScanResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.PartCheckoutHistoryResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.PartResponse;
import com.suachuabientan.system_internal.modules.warehouse.enums.CheckoutStatus;
import com.suachuabientan.system_internal.modules.warehouse.service.PartService;
import com.suachuabientan.system_internal.security.authorization.RoleExpressions;
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

import java.util.List;
import java.util.UUID;

@Tag(name = "Parts", description = "Quản lý kho linh kiện")
@RestController
@RequestMapping("/api/v1/parts")
@RequiredArgsConstructor
public class PartController {
    private final PartService partService;

    @Operation(summary = "Danh sách linh kiện")
    @GetMapping
    @PreAuthorize(RoleExpressions.WAREHOUSE_VIEW)
    public ResponseEntity<ApiResponse<Page<PartResponse>>> getAll(
            @RequestParam(required = false) String keyword,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(partService.getAll(keyword, pageable)));
    }

    @Operation(summary = "Chi tiết linh kiện")
    @GetMapping("/{id}")
    @PreAuthorize(RoleExpressions.WAREHOUSE_VIEW)
    public ResponseEntity<ApiResponse<PartResponse>> getById(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(partService.getById(id)));
    }

    @Operation(summary = "Tạo linh kiện mới")
    @PostMapping
    @PreAuthorize(RoleExpressions.WAREHOUSE_MANAGE)
    public ResponseEntity<ApiResponse<PartResponse>> create(
            @Valid @RequestBody CreatePartRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = extractUserId(userDetails);
        return ResponseEntity.status(201)
                .body(ApiResponse.created(partService.create(request, userId)));
    }

    @Operation(summary = "Cập nhật linh kiện")
    @PatchMapping("/{id}")
    @PreAuthorize(RoleExpressions.WAREHOUSE_MANAGE)
    public ResponseEntity<ApiResponse<PartResponse>> update(
            @PathVariable UUID id,
            @Valid @RequestBody UpdatePartRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = extractUserId(userDetails);
        return ResponseEntity.ok(ApiResponse.success(partService.update(id, request, userId)));
    }

    @Operation(summary = "Xoá linh kiện")
    @DeleteMapping("/{id}")
    @PreAuthorize(RoleExpressions.WAREHOUSE_DELETE)
    public ResponseEntity<ApiResponse<Void>> delete(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {
        partService.delete(id, extractUserId(userDetails));
        return ResponseEntity.ok(ApiResponse.success(null, "Xoá linh kiện thành công"));
    }

    @Operation(summary = "Điều chỉnh số lượng tồn kho của linh kiện")
    @PostMapping("/{id}/adjust-stock")
    @PreAuthorize(RoleExpressions.WAREHOUSE_MANAGE)
    public ResponseEntity<ApiResponse<PartResponse>> adjustStock(
            @PathVariable UUID id,
            @Valid @RequestBody AdjustStockRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = extractUserId(userDetails);
        return ResponseEntity.ok(ApiResponse.success(
                partService.adjustStock(id, request, userId),
                "Điều chỉnh số lượng tồn kho thành công"
        ));
    }

    @Operation(summary = "Nhập danh sách linh kiện hàng loạt từ Excel/CSV")
    @PostMapping("/bulk-import")
    @PreAuthorize(RoleExpressions.WAREHOUSE_MANAGE)
    public ResponseEntity<ApiResponse<BulkImportPartResponse>> bulkImport(
            @Valid @RequestBody BulkImportPartRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = extractUserId(userDetails);
        return ResponseEntity.ok(ApiResponse.success(
                partService.bulkImport(request, userId),
                "Nhập linh kiện hàng loạt thành công"
        ));
    }

    @Operation(summary = "Quét mã QR / Nhập mã vị trí kho — hiển thị tất cả linh kiện tại vị trí đó")
    @GetMapping("/locations/scan/{codeOrQr}")
    @PreAuthorize(RoleExpressions.WAREHOUSE_VIEW)
    public ResponseEntity<ApiResponse<LocationScanResponse>> scanLocationQr(@PathVariable String codeOrQr) {
        return ResponseEntity.ok(ApiResponse.success(partService.scanLocationQr(codeOrQr)));
    }

    @Operation(summary = "Lấy linh kiện ra khỏi vị trí kho (Checkout)")
    @PostMapping("/{id}/checkout")
    @PreAuthorize(RoleExpressions.WAREHOUSE_MANAGE)
    public ResponseEntity<ApiResponse<PartCheckoutHistoryResponse>> checkoutPart(
            @PathVariable UUID id,
            @Valid @RequestBody PartCheckoutRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = extractUserId(userDetails);
        return ResponseEntity.ok(ApiResponse.success(
                partService.checkoutPart(id, request, userId),
                "Lấy linh kiện thành công"
        ));
    }

    @Operation(summary = "Trả linh kiện về vị trí kho (Return)")
    @PostMapping("/checkouts/{checkoutId}/return")
    @PreAuthorize(RoleExpressions.WAREHOUSE_MANAGE)
    public ResponseEntity<ApiResponse<PartCheckoutHistoryResponse>> returnPart(
            @PathVariable UUID checkoutId,
            @Valid @RequestBody PartReturnRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = extractUserId(userDetails);
        return ResponseEntity.ok(ApiResponse.success(
                partService.returnPart(checkoutId, request, userId),
                "Trả linh kiện thành công"
        ));
    }

    @Operation(summary = "Xem nhật ký lấy và trả linh kiện (Part Activity Log)")
    @GetMapping("/checkouts/history")
    @PreAuthorize(RoleExpressions.WAREHOUSE_VIEW)
    public ResponseEntity<ApiResponse<Page<PartCheckoutHistoryResponse>>> getCheckoutHistory(
            @RequestParam(required = false) UUID partId,
            @RequestParam(required = false) UUID locationId,
            @RequestParam(required = false) UUID userId,
            @RequestParam(required = false) CheckoutStatus status,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(
                partService.getCheckoutHistory(partId, locationId, userId, status, pageable)
        ));
    }

    @Operation(summary = "Danh sách tất cả danh mục")
    @GetMapping("/categories")
    @PreAuthorize(RoleExpressions.WAREHOUSE_VIEW)
    public ResponseEntity<ApiResponse<List<CategoryInfo>>> getCategories() {
        return ResponseEntity.ok(ApiResponse.success(partService.getCategories()));
    }

    @Operation(summary = "Danh sách tất cả vị trí lưu kho")
    @GetMapping("/locations")
    @PreAuthorize(RoleExpressions.WAREHOUSE_VIEW)
    public ResponseEntity<ApiResponse<List<LocationInfo>>> getLocations() {
        return ResponseEntity.ok(ApiResponse.success(partService.getLocations()));
    }

    @Operation(summary = "Thêm vị trí kho mới kèm mã QR")
    @PostMapping("/locations")
    @PreAuthorize(RoleExpressions.WAREHOUSE_MANAGE)
    public ResponseEntity<ApiResponse<LocationInfo>> createLocation(
            @Valid @RequestBody CreateStoreLocationRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = extractUserId(userDetails);
        return ResponseEntity.status(201)
                .body(ApiResponse.created(partService.createLocation(request, userId)));
    }

    @Operation(summary = "Cập nhật thông tin vị trí kho")
    @PatchMapping("/locations/{id}")
    @PreAuthorize(RoleExpressions.WAREHOUSE_MANAGE)
    public ResponseEntity<ApiResponse<LocationInfo>> updateLocation(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateStoreLocationRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = extractUserId(userDetails);
        return ResponseEntity.ok(ApiResponse.success(
                partService.updateLocation(id, request, userId),
                "Cập nhật vị trí kho thành công"
        ));
    }

    @Operation(summary = "Xóa vị trí kho")
    @DeleteMapping("/locations/{id}")
    @PreAuthorize(RoleExpressions.WAREHOUSE_DELETE)
    public ResponseEntity<ApiResponse<Void>> deleteLocation(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = extractUserId(userDetails);
        partService.deleteLocation(id, userId);
        return ResponseEntity.ok(ApiResponse.success(null, "Xóa vị trí kho thành công"));
    }

    private UUID extractUserId(UserDetails userDetails) {
        return ((CustomUserDetails) userDetails).getUserId();
    }
}
