package com.suachuabientan.system_internal.modules.attendance.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.attendance.dto.request.FieldWorkRequest;
import com.suachuabientan.system_internal.modules.attendance.dto.response.FieldWorkDayResponse;
import com.suachuabientan.system_internal.modules.attendance.service.FieldWorkService;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/attendance/me/field-work")
@RequiredArgsConstructor
public class FieldWorkController {
    private final FieldWorkService service;

    @PutMapping("/{date}")
    public ApiResponse<FieldWorkDayResponse> save(
            @PathVariable @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @Valid @RequestBody FieldWorkRequest request,
            @AuthenticationPrincipal CustomUserDetails user) {
        return ApiResponse.success(service.save(user.getUserId(), date, request.note()));
    }

    @DeleteMapping("/{date}")
    public ApiResponse<Void> remove(
            @PathVariable @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @AuthenticationPrincipal CustomUserDetails user) {
        service.remove(user.getUserId(), date);
        return ApiResponse.success(null);
    }

    @GetMapping
    public ApiResponse<List<FieldWorkDayResponse>> list(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @AuthenticationPrincipal CustomUserDetails user) {
        return ApiResponse.success(service.list(user.getUserId(), from, to));
    }
}
