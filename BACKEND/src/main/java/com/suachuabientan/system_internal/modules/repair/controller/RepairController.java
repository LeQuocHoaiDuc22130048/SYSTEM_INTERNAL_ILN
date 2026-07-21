package com.suachuabientan.system_internal.modules.repair.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.repair.dto.request.AssignRequest;
import com.suachuabientan.system_internal.modules.repair.dto.request.CreateRepairOrderRequest;
import com.suachuabientan.system_internal.modules.repair.dto.request.UpdateRepairOrderRequest;
import com.suachuabientan.system_internal.modules.repair.dto.request.ReorderRequest;
import com.suachuabientan.system_internal.modules.repair.dto.request.UpdateStatusRequest;
import com.suachuabientan.system_internal.modules.repair.dto.response.RepairOrderResponse;
import com.suachuabientan.system_internal.modules.repair.dto.response.RepairTimelineResponse;
import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import com.suachuabientan.system_internal.modules.repair.enums.RepairMediaType;
import com.suachuabientan.system_internal.modules.repair.service.RepairService;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

@Tag(name = "Repair Orders", description = "Quản lý đơn sửa chữa")
@RestController
@RequestMapping("/api/v1/repair-orders")
@RequiredArgsConstructor
public class RepairController {
    private final RepairService repairService;

    // ── Tạo & Danh sách ───────────────────────────────────────

    @Operation(summary = "Tạo đơn sửa chữa mới")
    @PostMapping
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'EMPLOYEE', 'TECHNICIAN')")
    public ResponseEntity<ApiResponse<RepairOrderResponse>> create(
            @Valid @RequestBody CreateRepairOrderRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.status(201)
                .body(ApiResponse.created(repairService.create(request, userDetails.getUserId())));
    }

    @Operation(summary = "Chỉnh sửa thông tin đơn sửa chữa")
    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'TECHNICIAN')")
    public ResponseEntity<ApiResponse<RepairOrderResponse>> update(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateRepairOrderRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                repairService.update(id, request, userDetails)));
    }

    @Operation(summary = "Danh sách đơn — filter theo status, keyword, kỹ thuật viên")
    @GetMapping
    public ResponseEntity<ApiResponse<Page<RepairOrderResponse>>> getAll(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) RepairStatus status,
            @RequestParam(required = false) UUID assignedTo,
            @PageableDefault(size = 20) Pageable pageable,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                repairService.getAll(keyword, status, assignedTo, pageable, userDetails)));
    }

    @Operation(summary = "Chi tiết đơn sửa chữa")
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<RepairOrderResponse>> getById(
            @PathVariable UUID id,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(repairService.getById(id, userDetails)));
    }

    // ── Phân công ─────────────────────────────────────────────

    @Operation(summary = "Phân công kỹ thuật viên cho đơn")
    @PutMapping("/{id}/assign")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'TECHNICIAN')")
    public ResponseEntity<ApiResponse<RepairOrderResponse>> assign(
            @PathVariable UUID id,
            @Valid @RequestBody AssignRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                repairService.assign(id, request, userDetails.getUserId())));
    }

    // ── Cập nhật trạng thái ───────────────────────────────────

    @Operation(summary = "Cập nhật trạng thái đơn")
    @PatchMapping("/{id}/status")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'EMPLOYEE', 'TECHNICIAN')")
    public ResponseEntity<ApiResponse<RepairOrderResponse>> updateStatus(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateStatusRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                repairService.updateStatus(id, request, userDetails)));
    }

    // ── Sắp xếp ưu tiên ──────────────────────────────────────

    @Operation(summary = "Cập nhật thứ tự ưu tiên hàng loạt — Manager kéo thả")
    @PutMapping("/reorder")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<ApiResponse<Void>> reorder(
            @Valid @RequestBody ReorderRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        repairService.reorder(request, userDetails.getUserId());
        return ResponseEntity.ok(ApiResponse.success(null, "Cập nhật thứ tự thành công"));
    }

    // ── Huỷ đơn ──────────────────────────────────────────────

    @Operation(summary = "Huỷ đơn sửa chữa")
    @PatchMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<ApiResponse<RepairOrderResponse>> cancel(
            @PathVariable UUID id,
            @RequestParam(required = false) String reason,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                repairService.cancel(id, reason, userDetails.getUserId())));
    }

    // ── Timeline ──────────────────────────────────────────────

    @Operation(summary = "Lịch sử vòng đời đơn")
    @GetMapping("/{id}/timeline")
    public ResponseEntity<ApiResponse<List<RepairTimelineResponse>>> getTimeline(
            @PathVariable UUID id,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(repairService.getTimeline(id, userDetails)));
    }

    // ── Ảnh đính kèm ─────────────────────────────────────────

    @Operation(summary = "Thêm ảnh vào đơn sửa chữa")
    @PostMapping("/{id}/images")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'EMPLOYEE', 'TECHNICIAN')")
    public ResponseEntity<ApiResponse<RepairOrderResponse.ImageInfo>> addImage(
            @PathVariable UUID id,
            @RequestParam String imageUrl,
            @RequestParam(required = false) String caption,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.status(201).body(ApiResponse.created(
                repairService.addImage(id, imageUrl, caption, userDetails)));
    }

    @Operation(summary = "Upload anh hoac video vao don sua chua")
    @PostMapping(value = "/{id}/media", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'EMPLOYEE', 'TECHNICIAN')")
    public ResponseEntity<ApiResponse<RepairOrderResponse.ImageInfo>> uploadMedia(
            @PathVariable UUID id,
            @RequestPart("file") MultipartFile file,
            @RequestParam RepairMediaType type,
            @RequestParam(required = false) String caption,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.status(201).body(ApiResponse.created(
                repairService.addMedia(id, file, type, caption, userDetails)));
    }

    @Operation(summary = "Xóa đơn sửa chữa")
    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'TECHNICIAN')")
    public ResponseEntity<ApiResponse<Void>> delete(
            @PathVariable UUID id,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        repairService.delete(id, userDetails);
        return ResponseEntity.ok(ApiResponse.success(null));
    }

    @Operation(summary = "Xóa hình ảnh hoặc video khỏi đơn sửa chữa")
    @DeleteMapping("/media/{mediaId}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'EMPLOYEE', 'TECHNICIAN')")
    public ResponseEntity<ApiResponse<Void>> deleteMedia(
            @PathVariable UUID mediaId,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        repairService.deleteMedia(mediaId, userDetails);
        return ResponseEntity.ok(ApiResponse.success(null));
    }
}
