package com.suachuabientan.system_internal.modules.device.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.device.dto.DeviceRequest;
import com.suachuabientan.system_internal.modules.device.dto.DeviceResponse;
import com.suachuabientan.system_internal.modules.device.service.DeviceService;
import com.suachuabientan.system_internal.security.authorization.RoleExpressions;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@Tag(name = "Device", description = "Quản lý và giám sát thiết bị trong hệ thống")
@RestController
@RequestMapping("/api/v1/devices")
@RequiredArgsConstructor
public class DeviceController {

    private final DeviceService deviceService;

    @Operation(summary = "Lấy danh sách thiết bị và trạng thái hoạt động")
    @GetMapping
    @PreAuthorize(RoleExpressions.ANY_ACTIVE_USER)
    public ResponseEntity<ApiResponse<List<DeviceResponse>>> getDevices() {
        return ResponseEntity.ok(ApiResponse.success(deviceService.getDevices()));
    }

    @Operation(summary = "Thêm thiết bị mới")
    @PostMapping
    @PreAuthorize(RoleExpressions.MANAGER_OR_ABOVE)
    public ResponseEntity<ApiResponse<DeviceResponse>> createDevice(
            @Valid @RequestBody DeviceRequest request,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        UUID userId = extractUserId(userDetails);
        return ResponseEntity.status(201)
                .body(ApiResponse.created(deviceService.createDevice(request, userId)));
    }

    @Operation(summary = "Cập nhật thông tin thiết bị")
    @PutMapping("/{id}")
    @PreAuthorize(RoleExpressions.MANAGER_OR_ABOVE)
    public ResponseEntity<ApiResponse<DeviceResponse>> updateDevice(
            @PathVariable UUID id,
            @Valid @RequestBody DeviceRequest request,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        UUID userId = extractUserId(userDetails);
        return ResponseEntity.ok(ApiResponse.success(deviceService.updateDevice(id, request, userId)));
    }

    @Operation(summary = "Xoá thiết bị")
    @DeleteMapping("/{id}")
    @PreAuthorize(RoleExpressions.MANAGER_OR_ABOVE)
    public ResponseEntity<ApiResponse<Void>> deleteDevice(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        UUID userId = extractUserId(userDetails);
        deviceService.deleteDevice(id, userId);
        return ResponseEntity.ok(ApiResponse.success(null, "Xoá thiết bị thành công"));
    }

    @Operation(summary = "Toggle trạng thái Online/Offline (Simulate)")
    @PostMapping("/{id}/toggle")
    @PreAuthorize(RoleExpressions.MANAGER_OR_ABOVE)
    public ResponseEntity<ApiResponse<DeviceResponse>> toggleDeviceStatus(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        UUID userId = extractUserId(userDetails);
        return ResponseEntity.ok(ApiResponse.success(deviceService.toggleDeviceStatus(id, userId)));
    }

    @Operation(summary = "Gửi lệnh ping tới thiết bị")
    @PostMapping("/{id}/ping")
    @PreAuthorize(RoleExpressions.ANY_ACTIVE_USER)
    public ResponseEntity<ApiResponse<DeviceResponse>> pingDevice(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        UUID userId = extractUserId(userDetails);
        return ResponseEntity.ok(ApiResponse.success(deviceService.pingDevice(id, userId)));
    }

    @Operation(summary = "API nhận Heartbeat từ thiết bị vật lý")
    @PostMapping("/heartbeat")
    public ResponseEntity<ApiResponse<Void>> heartbeat(@RequestParam String deviceId) {
        deviceService.receiveHeartbeat(deviceId);
        return ResponseEntity.ok(ApiResponse.success(null, "Heartbeat received"));
    }

    private UUID extractUserId(UserDetails userDetails) {
        return ((CustomUserDetails) userDetails).getUserId();
    }
}
