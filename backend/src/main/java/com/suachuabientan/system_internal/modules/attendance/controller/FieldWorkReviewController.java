package com.suachuabientan.system_internal.modules.attendance.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.attendance.dto.response.FieldWorkDayResponse;
import com.suachuabientan.system_internal.modules.attendance.service.FieldWorkService;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import java.util.*;

@RestController
@RequestMapping("/api/attendance/field-work")
@PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
@RequiredArgsConstructor
public class FieldWorkReviewController {
    private final FieldWorkService service;
    public record ReviewRequest(@NotNull Boolean approve, @NotNull Long version) {}
    @GetMapping("/pending")
    public ApiResponse<List<FieldWorkDayResponse>> pending() {
        return ApiResponse.success(service.pending());
    }
    @PutMapping("/{id}/review")
    public ApiResponse<FieldWorkDayResponse> review(@PathVariable UUID id,
            @Valid @RequestBody ReviewRequest request, @AuthenticationPrincipal CustomUserDetails user) {
        return ApiResponse.success(service.review(id, user.getUserId(), request.approve(), request.version()));
    }
}
