package com.suachuabientan.system_internal.modules.employee.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.employee.dto.request.EnrollFaceRequest;
import com.suachuabientan.system_internal.modules.employee.dto.request.UpdateEmployeeRequest;
import com.suachuabientan.system_internal.modules.employee.dto.response.EmployeeDetailResponse;
import com.suachuabientan.system_internal.modules.employee.dto.response.EmployeeEmbeddingDeltaResponse;
import com.suachuabientan.system_internal.modules.employee.dto.response.EmployeeEmbeddingMetadataResponse;
import com.suachuabientan.system_internal.modules.employee.dto.response.EmployeeFaceEmbeddingResponse;
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

import java.util.List;
import java.time.Instant;
import java.util.UUID;

@Tag(name = "Employees", description = "Quản lý nhân viên")
@RestController
@RequestMapping("/api/v1/employees")
@RequiredArgsConstructor
public class EmployeeController {
    private final EmployeeService employeeService;

    @GetMapping("/repair-assignees")
    @PreAuthorize("hasAuthority('REPAIR_ASSIGN') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<List<com.suachuabientan.system_internal.modules.employee.dto.response.RepairAssigneeResponse>>> getRepairAssignees() {
        return ResponseEntity.ok(ApiResponse.success(employeeService.getRepairAssignees()));
    }

    // ── Danh sách & Chi tiết ──────────────────────────────────

    @Operation(summary = "Tìm kiếm danh sách nhân viên")
    @GetMapping
    @PreAuthorize("hasAnyAuthority('EMPLOYEE_VIEW','EMPLOYEE_STATUS_UPDATE','EMPLOYEE_FACE_ENROLL','EMPLOYEE_FACE_DELETE') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<Page<EmployeeDetailResponse>>> search(
            @RequestParam(required = false) String keyword,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(
                employeeService.searchEmployees(keyword, pageable)));
    }

    @Operation(summary = "Chi tiết nhân viên")
    @GetMapping("/{id}")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasAuthority('EMPLOYEE_VIEW') or (hasAuthority('PROFILE_VIEW') and #id == principal.userId)")
    public ResponseEntity<ApiResponse<EmployeeDetailResponse>> getById(
            @PathVariable UUID id,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        // Nhân viên chỉ xem được thông tin của mình, Manager+ xem được tất cả
        if (!id.equals(userDetails.getUserId()) && !userDetails.hasPermission("EMPLOYEE_VIEW")) {
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

    @Operation(summary = "Danh sach embedding khuon mat de mobile sync offline")
    @GetMapping("/embeddings")
    @PreAuthorize("hasAuthority('ATTENDANCE_KIOSK_USE') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<List<EmployeeFaceEmbeddingResponse>>> getFaceEmbeddings() {
        return ResponseEntity.ok(ApiResponse.success(employeeService.getFaceEmbeddings()));
    }

    @Operation(summary = "Metadata version/checksum embedding khuon mat")
    @GetMapping("/embeddings/meta")
    @PreAuthorize("hasAuthority('ATTENDANCE_KIOSK_USE') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<EmployeeEmbeddingMetadataResponse>> getFaceEmbeddingMetadata() {
        return ResponseEntity.ok(ApiResponse.success(employeeService.getFaceEmbeddingMetadata()));
    }

    @Operation(summary = "Delta embedding khuon mat thay doi tu moc since")
    @GetMapping("/embeddings/changes")
    @PreAuthorize("hasAuthority('ATTENDANCE_KIOSK_USE') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<EmployeeEmbeddingDeltaResponse>> getFaceEmbeddingChanges(
            @RequestParam(required = false) Instant since) {
        return ResponseEntity.ok(ApiResponse.success(employeeService.getFaceEmbeddingChanges(since)));
    }

    // ── Cập nhật thông tin ────────────────────────────────────

    @Operation(summary = "Cập nhật thông tin nhân viên")
    @PatchMapping("/{id}")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasAuthority('EMPLOYEE_UPDATE') or (hasAuthority('PROFILE_UPDATE_SELF') and #id == principal.userId)")
    public ResponseEntity<ApiResponse<EmployeeDetailResponse>> update(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateEmployeeRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                employeeService.update(id, request,
                        userDetails.getUserId(), userDetails.hasPermission("EMPLOYEE_UPDATE"))));
    }

    // ── Khoá / Mở khoá ───────────────────────────────────────

    @Operation(summary = "Khoá tài khoản nhân viên")
    @PatchMapping("/{id}/suspend")
    @PreAuthorize("hasAuthority('EMPLOYEE_STATUS_UPDATE') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<EmployeeDetailResponse>> suspend(
            @PathVariable UUID id,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                employeeService.suspend(id, userDetails.getUserId())));
    }

    @Operation(summary = "Mở khoá tài khoản nhân viên")
    @PatchMapping("/{id}/activate")
    @PreAuthorize("hasAuthority('EMPLOYEE_STATUS_UPDATE') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<EmployeeDetailResponse>> activate(
            @PathVariable UUID id,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                employeeService.activate(id, userDetails.getUserId())));
    }

    // ── Enroll khuôn mặt ─────────────────────────────────────

    @Operation(summary = "Đăng ký khuôn mặt nhân viên — chỉ Admin")
    @PostMapping("/{id}/face")
    @PreAuthorize("hasAuthority('EMPLOYEE_FACE_ENROLL') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<EmployeeDetailResponse>> enrollFace(
            @PathVariable UUID id,
            @Valid @RequestBody EnrollFaceRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                employeeService.enrollFace(
                        id,
                        request,
                        userDetails.getUserId()),
                "Đăng ký khuôn mặt thành công"));
    }

    @Operation(summary = "Xoa khuon mat da dang ky cua nhan vien")
    @DeleteMapping("/{id}/face")
    @PreAuthorize("hasAuthority('EMPLOYEE_FACE_DELETE') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<EmployeeDetailResponse>> deleteFace(
            @PathVariable UUID id,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                employeeService.deleteFace(id, userDetails.getUserId()),
                "Da xoa khuon mat da dang ky"));
    }
}
