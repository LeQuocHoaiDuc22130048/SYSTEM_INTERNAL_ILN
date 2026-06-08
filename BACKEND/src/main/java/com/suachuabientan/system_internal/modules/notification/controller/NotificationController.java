package com.suachuabientan.system_internal.modules.notification.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.notification.dto.request.UpdateDeviceTokenRequest;
import com.suachuabientan.system_internal.modules.notification.dto.response.NotificationResponse;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@Tag(name = "Notification", description = "Thông báo in-app, push và realtime")
@RestController
@RequestMapping("/api/v1/notifications")
@RequiredArgsConstructor
public class NotificationController {
    private final NotificationService notificationService;

    @Operation(summary = "Danh sách thông báo của người đang đăng nhập")
    @GetMapping
    public ResponseEntity<ApiResponse<Page<NotificationResponse>>> getMyNotifications(
            @PageableDefault(size = 20) Pageable pageable,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                notificationService.getMyNotifications(userDetails.getUserId(), pageable)));
    }

    @Operation(summary = "Đếm số thông báo chưa đọc")
    @GetMapping("/unread-count")
    public ResponseEntity<ApiResponse<Map<String, Long>>> countUnread(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                Map.of("unreadCount", notificationService.countUnread(userDetails.getUserId()))));
    }

    @Operation(summary = "Đánh dấu một thông báo đã đọc")
    @PutMapping("/{id}/read")
    public ResponseEntity<ApiResponse<NotificationResponse>> markAsRead(
            @PathVariable UUID id,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                notificationService.markAsRead(id, userDetails.getUserId()),
                "Đã đánh dấu thông báo là đã đọc"));
    }

    @Operation(summary = "Đánh dấu tất cả thông báo đã đọc")
    @PutMapping("/read-all")
    public ResponseEntity<ApiResponse<Map<String, Long>>> markAllAsRead(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        long updated = notificationService.markAllAsRead(userDetails.getUserId());
        return ResponseEntity.ok(ApiResponse.success(
                Map.of("updatedCount", updated),
                "Đã đánh dấu tất cả thông báo là đã đọc"));
    }

    @Operation(summary = "Cập nhật Firebase device token của người đang đăng nhập")
    @PutMapping("/device-token")
    public ResponseEntity<ApiResponse<Void>> updateDeviceToken(
            @Valid @RequestBody UpdateDeviceTokenRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        notificationService.updateDeviceToken(userDetails.getUserId(), request.deviceToken());
        return ResponseEntity.ok(ApiResponse.success(null, "Đã cập nhật device token"));
    }

    @Operation(summary = "Hủy Firebase device token khi đăng xuất thiết bị hiện tại")
    @DeleteMapping("/device-token")
    public ResponseEntity<ApiResponse<Void>> clearDeviceToken(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        notificationService.clearDeviceToken(userDetails.getUserId());
        return ResponseEntity.ok(ApiResponse.success(null, "Đã hủy device token"));
    }
}
