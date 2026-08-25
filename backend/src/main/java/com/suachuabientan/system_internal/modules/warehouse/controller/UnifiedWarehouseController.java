package com.suachuabientan.system_internal.modules.warehouse.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.AdjustStockRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.LocationScanResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.UnifiedWarehouseItemResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.UnifiedWarehouseSummaryResponse;
import com.suachuabientan.system_internal.modules.warehouse.service.PartService;
import com.suachuabientan.system_internal.modules.warehouse.service.UnifiedWarehouseService;
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

import java.util.Map;
import java.util.UUID;

@Tag(name = "Unified Warehouse", description = "Quản lý kho thống nhất (Bo mạch và Linh kiện)")
@RestController
@RequestMapping("/api/v1/warehouse")
@RequiredArgsConstructor
public class UnifiedWarehouseController {

    private final UnifiedWarehouseService unifiedWarehouseService;
    private final PartService partService;

    @Operation(summary = "Danh sách mặt hàng trong kho thống nhất (có tìm kiếm, lọc theo loại, trạng thái)")
    @GetMapping("/inventory")
    @PreAuthorize(RoleExpressions.WAREHOUSE_VIEW)
    public ResponseEntity<ApiResponse<Page<UnifiedWarehouseItemResponse>>> getInventory(
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String location,
            @PageableDefault(size = 200) Pageable pageable
    ) {
        return ResponseEntity.ok(ApiResponse.success(
                unifiedWarehouseService.getInventory(type, keyword, status, location, pageable)
        ));
    }

    @Operation(summary = "Thống kê tổng hợp toàn bộ kho")
    @GetMapping("/summary")
    @PreAuthorize(RoleExpressions.WAREHOUSE_VIEW)
    public ResponseEntity<ApiResponse<UnifiedWarehouseSummaryResponse>> getSummary() {
        return ResponseEntity.ok(ApiResponse.success(unifiedWarehouseService.getSummary()));
    }

    @Operation(summary = "Quét mã QR thông minh tại kho (vị trí kệ, bo mạch hoặc linh kiện)")
    @GetMapping("/scan/{codeOrQr}")
    @PreAuthorize(RoleExpressions.WAREHOUSE_VIEW)
    public ResponseEntity<ApiResponse<LocationScanResponse>> scanQr(@PathVariable String codeOrQr) {
        return ResponseEntity.ok(ApiResponse.success(partService.scanLocationQr(codeOrQr)));
    }

    @Operation(summary = "Xuất kho mặt hàng (Bo mạch hoặc Linh kiện)")
    @PostMapping("/items/{id}/checkout")
    @PreAuthorize(RoleExpressions.WAREHOUSE_MANAGE)
    public ResponseEntity<ApiResponse<Object>> checkoutItem(
            @PathVariable UUID id,
            @RequestParam(defaultValue = "PART") String itemType,
            @RequestBody Map<String, Object> payload,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        UUID userId = extractUserId(userDetails);
        Object result = unifiedWarehouseService.checkoutUnifiedItem(id, itemType, payload, userId);
        return ResponseEntity.ok(ApiResponse.success(result, "Lấy hàng khỏi kho thành công"));
    }

    @Operation(summary = "Điều chỉnh tồn kho mặt hàng")
    @PostMapping("/items/{id}/adjust")
    @PreAuthorize(RoleExpressions.WAREHOUSE_MANAGE)
    public ResponseEntity<ApiResponse<Void>> adjustStock(
            @PathVariable UUID id,
            @RequestParam(defaultValue = "PART") String itemType,
            @Valid @RequestBody AdjustStockRequest request,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        UUID userId = extractUserId(userDetails);
        unifiedWarehouseService.adjustUnifiedItemStock(id, itemType, request, userId);
        return ResponseEntity.ok(ApiResponse.success(null, "Điều chỉnh tồn kho thành công"));
    }

    @Operation(summary = "Xóa mặt hàng khỏi kho")
    @DeleteMapping("/items/{id}")
    @PreAuthorize(RoleExpressions.WAREHOUSE_DELETE)
    public ResponseEntity<ApiResponse<Void>> deleteItem(
            @PathVariable UUID id,
            @RequestParam(defaultValue = "PART") String itemType,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        UUID userId = extractUserId(userDetails);
        unifiedWarehouseService.deleteUnifiedItem(id, itemType, userId);
        return ResponseEntity.ok(ApiResponse.success(null, "Xóa mặt hàng thành công"));
    }

    private UUID extractUserId(UserDetails userDetails) {
        if (userDetails instanceof CustomUserDetails customUserDetails) {
            return customUserDetails.getUserId();
        }
        throw new com.suachuabientan.system_internal.common.exception.BusinessException(
                "Người dùng chưa được xác thực hợp lệ", 401);
    }
}
