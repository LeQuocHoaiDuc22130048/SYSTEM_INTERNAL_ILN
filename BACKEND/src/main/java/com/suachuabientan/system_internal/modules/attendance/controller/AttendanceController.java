package com.suachuabientan.system_internal.modules.attendance.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.attendance.dto.request.CheckinRequest;
import com.suachuabientan.system_internal.modules.attendance.dto.request.CreateScheduleRequest;
import com.suachuabientan.system_internal.modules.attendance.dto.request.ManualCheckinRequest;
import com.suachuabientan.system_internal.modules.attendance.dto.response.AttendanceResponse;
import com.suachuabientan.system_internal.modules.attendance.dto.response.DailyAttendanceResponse;
import com.suachuabientan.system_internal.modules.attendance.dto.response.WorkScheduleResponse;
import com.suachuabientan.system_internal.modules.attendance.service.AttendanceService;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Tag(name = "Attendance", description = "Chấm công nội bộ")
@RestController
@RequestMapping("/api/v1/attendance")
@RequiredArgsConstructor
public class AttendanceController {
    private final AttendanceService attendanceService;

    @Operation(summary = "Cham cong noi bo cho nguoi dang dang nhap")
    @PostMapping("/check")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'EMPLOYEE')")
    public ResponseEntity<ApiResponse<AttendanceResponse>> check(
            @RequestBody(required = false) CheckinRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        CheckinRequest safeRequest = request != null ? request : new CheckinRequest(null, null);
        return ResponseEntity.ok(ApiResponse.success(
                attendanceService.check(userDetails.getUserId(), safeRequest),
                "Cham cong thanh cong"));
    }

    @Operation(summary = "Tong hop cham cong hom nay cua nguoi dang dang nhap")
    @GetMapping("/me/today")
    public ResponseEntity<ApiResponse<DailyAttendanceResponse>> getMyToday(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(attendanceService.getMyToday(userDetails.getUserId())));
    }

    @Operation(summary = "Lich su cham cong cua nguoi dang dang nhap")
    @GetMapping("/me/history")
    public ResponseEntity<ApiResponse<Page<AttendanceResponse>>> getMyHistory(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @PageableDefault(size = 20) Pageable pageable,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                attendanceService.getHistory(userDetails.getUserId(), from, to, pageable)));
    }

    @Operation(summary = "Cham cong tay cho nhan vien")
    @PostMapping("/manual")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<ApiResponse<AttendanceResponse>> manualCheck(
            @Valid @RequestBody ManualCheckinRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.status(201).body(ApiResponse.created(
                attendanceService.manualCheck(request, userDetails.getUserId())));
    }

    @Operation(summary = "Xem cham cong theo ngay cua mot nhan vien")
    @GetMapping("/employees/{employeeId}/daily")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<ApiResponse<DailyAttendanceResponse>> getDaily(
            @PathVariable UUID employeeId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return ResponseEntity.ok(ApiResponse.success(attendanceService.getDaily(employeeId, date)));
    }

    @Operation(summary = "Lich su cham cong cua mot nhan vien")
    @GetMapping("/employees/{employeeId}/history")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<ApiResponse<Page<AttendanceResponse>>> getEmployeeHistory(
            @PathVariable UUID employeeId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(
                attendanceService.getHistory(employeeId, from, to, pageable)));
    }

    @Operation(summary = "Bao cao cham cong toan bo nhan vien theo ngay")
    @GetMapping("/report")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<ApiResponse<List<DailyAttendanceResponse>>> getReport(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return ResponseEntity.ok(ApiResponse.success(attendanceService.getReport(date)));
    }

    @Operation(summary = "Tao hoac cap nhat lich lam viec cho nhan vien")
    @PostMapping("/schedules")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<ApiResponse<WorkScheduleResponse>> createOrUpdateSchedule(
            @Valid @RequestBody CreateScheduleRequest request) {
        return ResponseEntity.status(201)
                .body(ApiResponse.created(attendanceService.createOrUpdateSchedule(request)));
    }

    @Operation(summary = "Xem lich lam viec cua mot nhan vien")
    @GetMapping("/employees/{employeeId}/schedules")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<ApiResponse<List<WorkScheduleResponse>>> getSchedules(
            @PathVariable UUID employeeId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ResponseEntity.ok(ApiResponse.success(attendanceService.getSchedules(employeeId, from, to)));
    }
}
