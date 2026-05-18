package com.suachuabientan.system_internal.modules.employee.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.employee.dto.request.UpdateEmployeeRequest;
import com.suachuabientan.system_internal.modules.employee.dto.response.EmployeeDetailResponse;
import com.suachuabientan.system_internal.modules.employee.service.EmployeeService;
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

import java.util.UUID;

@Tag(name = "Employees", description = "Quản lý nhân viên")
@RestController
@RequestMapping("/api/v1/employees")
@RequiredArgsConstructor
public class EmployeeController {
    private final EmployeeService employeeService;

    // ── Danh sách & Chi tiết ──────────────────────────────────

    @Operation(summary = "Tìm kiếm danh sách nhân viên")
    @GetMapping
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<ApiResponse<Page<EmployeeDetailResponse>>> search(
            @RequestParam(required = false) String keyword,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(
                employeeService.searchEmployees(keyword, pageable)));
    }

    @Operation(summary = "Chi tiết nhân viên")
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<EmployeeDetailResponse>> getById(
            @PathVariable UUID id,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        // Nhân viên chỉ xem được thông tin của mình, Manager+ xem được tất cả
        if (!id.equals(userDetails.getUserId()) && !userDetails.isManagerOrAbove()) {
            return ResponseEntity.status(403)
                    .body(ApiResponse.error(403, "Bạn không có quyền xem thông tin nhân viên này"));
        }
        return ResponseEntity.ok(ApiResponse.success(employeeService.getById(id)));
    }

    @Operation(summary = "Thông tin bản thân")
    @GetMapping("/me")
    public ResponseEntity<ApiResponse<EmployeeDetailResponse>> getMe(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                employeeService.getById(userDetails.getUserId())));
    }

    // ── Cập nhật thông tin ────────────────────────────────────

    @Operation(summary = "Cập nhật thông tin nhân viên")
    @PatchMapping("/{id}")
    public ResponseEntity<ApiResponse<EmployeeDetailResponse>> update(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateEmployeeRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                employeeService.update(id, request,
                        userDetails.getUserId(), userDetails.isManagerOrAbove())));
    }

    // ── Khoá / Mở khoá ───────────────────────────────────────

    @Operation(summary = "Khoá tài khoản nhân viên")
    @PatchMapping("/{id}/suspend")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<ApiResponse<EmployeeDetailResponse>> suspend(
            @PathVariable UUID id,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                employeeService.suspend(id, userDetails.getUserId())));
    }

    @Operation(summary = "Mở khoá tài khoản nhân viên")
    @PatchMapping("/{id}/activate")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<ApiResponse<EmployeeDetailResponse>> activate(
            @PathVariable UUID id,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                employeeService.activate(id, userDetails.getUserId())));
    }

    // ── Enroll khuôn mặt ─────────────────────────────────────

    @Operation(summary = "Đăng ký khuôn mặt nhân viên — chỉ Admin")
    @PostMapping("/{id}/face")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<ApiResponse<EmployeeDetailResponse>> enrollFace(
            @PathVariable UUID id,
            @RequestParam String faceEncoding,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                employeeService.enrollFace(id, faceEncoding, userDetails.getUserId()),
                "Đăng ký khuôn mặt thành công"));
    }
}
