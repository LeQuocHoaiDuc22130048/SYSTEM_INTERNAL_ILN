package com.suachuabientan.system_internal.modules.terminal.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.terminal.dto.SystemActivityDto;
import com.suachuabientan.system_internal.modules.terminal.dto.TerminalCommandRequest;
import com.suachuabientan.system_internal.modules.terminal.dto.TerminalCommandResponse;
import com.suachuabientan.system_internal.modules.terminal.service.SystemActivityBuffer;
import com.suachuabientan.system_internal.modules.terminal.service.TerminalCommandService;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.List;

@Tag(name = "Terminal & Activity Management", description = "Quản lý dòng lệnh và luồng hoạt động trực tiếp trên website")
@RestController
@RequestMapping("/api/v1/terminal")
@RequiredArgsConstructor
@PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('ADMIN') or hasAuthority('SYSTEM_TERMINAL')")
public class TerminalController {

    private final TerminalCommandService commandService;
    private final SystemActivityBuffer activityBuffer;

    @Operation(summary = "Thực thi câu lệnh quản trị terminal")
    @PostMapping("/exec")
    public ResponseEntity<ApiResponse<TerminalCommandResponse>> executeCommand(
            @Valid @RequestBody TerminalCommandRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        String username = userDetails != null ? userDetails.getUsername() : "admin";
        TerminalCommandResponse response = commandService.execute(request.command(), username);
        return ResponseEntity.ok(ApiResponse.success(response, "Thực thi lệnh thành công"));
    }

    @Operation(summary = "Lấy danh sách các hoạt động gần đây")
    @GetMapping("/activities")
    public ResponseEntity<ApiResponse<List<SystemActivityDto>>> getRecentActivities(
            @RequestParam(defaultValue = "50") int limit,
            @RequestParam(required = false) String category) {
        List<SystemActivityDto> list = activityBuffer.getRecent(limit, category);
        return ResponseEntity.ok(ApiResponse.success(list, "Lấy danh sách hoạt động thành công"));
    }

    @Operation(summary = "Kết nối luồng nhật ký hoạt động thời gian thực (SSE Stream)")
    @GetMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter streamActivities(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        String username = userDetails != null ? userDetails.getUsername() : "admin";
        return activityBuffer.createEmitter(username);
    }
}
