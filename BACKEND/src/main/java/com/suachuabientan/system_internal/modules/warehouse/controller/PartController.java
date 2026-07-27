package com.suachuabientan.system_internal.modules.warehouse.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.AdjustStockRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.CreatePartRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.UpdatePartRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.CategoryInfo;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.LocationInfo;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.PartResponse;
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

    private UUID extractUserId(UserDetails userDetails) {
        return ((CustomUserDetails) userDetails).getUserId();
    }
}
