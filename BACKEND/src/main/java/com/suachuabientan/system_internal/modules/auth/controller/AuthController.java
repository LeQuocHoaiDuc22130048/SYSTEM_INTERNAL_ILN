package com.suachuabientan.system_internal.modules.auth.controller;


import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.auth.dto.request.ApproveUserRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.ForgotPasswordRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.LoginRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.RefreshTokenRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.RegisterRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.RequestPasswordResetOtpRequest;
import com.suachuabientan.system_internal.modules.auth.dto.response.LoginResponse;
import com.suachuabientan.system_internal.modules.auth.dto.response.UserResponse;
import com.suachuabientan.system_internal.modules.auth.service.AuthService;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@Tag(name = "Auth", description = "Xác thực và quản lý tài khoản")
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {
    private final AuthService authService;

    // ── Public endpoints ──────────────────────────────────────────────────

    @Operation(summary = "Đăng ký tài khoản mới — status: PENDING_APPROVAL")
    @PostMapping("/register")
    public ResponseEntity<ApiResponse<UserResponse>> register(
            @Valid @RequestBody RegisterRequest request) {
        return ResponseEntity.status(201)
                .body(ApiResponse.created(authService.register(request)));
    }

    @Operation(summary = "Đăng nhập — trả access token + refresh token")
    @PostMapping("/login")
    public ResponseEntity<ApiResponse<LoginResponse>> login(
            @Valid @RequestBody LoginRequest request) {
        return ResponseEntity.ok(ApiResponse.success(authService.login(request)));
    }

    @Operation(summary = "Làm mới access token bằng refresh token")
    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<LoginResponse>> refresh(
            @Valid @RequestBody RefreshTokenRequest request) {
        return ResponseEntity.ok(ApiResponse.success(authService.refreshToken(request)));
    }

    @Operation(summary = "Gui ma OTP dat lai mat khau qua thong bao day cua thiet bi")
    @PostMapping("/forgot-password/otp")
    public ResponseEntity<ApiResponse<Void>> requestForgotPasswordOtp(
            @Valid @RequestBody RequestPasswordResetOtpRequest request) {
        authService.requestPasswordResetOtp(request);
        return ResponseEntity.ok(ApiResponse.success(null, "Da gui ma OTP"));
    }

    @Operation(summary = "Dat lai mat khau sau khi xac minh OTP")
    @PostMapping("/forgot-password")
    public ResponseEntity<ApiResponse<Void>> forgotPassword(
            @Valid @RequestBody ForgotPasswordRequest request) {
        authService.forgotPassword(request);
        return ResponseEntity.ok(ApiResponse.success(null, "Dat lai mat khau thanh cong"));
    }

    @Operation(summary = "Đăng xuất thiết bị hiện tại — revoke refresh token")
    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<Void>> logout(
            @Valid @RequestBody RefreshTokenRequest request) {
        authService.logout(request.refreshToken());
        return ResponseEntity.ok(ApiResponse.success(null, "Đăng xuất thành công"));
    }

    @Operation(summary = "Đăng xuất tất cả thiết bị")
    @PostMapping("/logout-all")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<ApiResponse<Void>> logoutAll(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        authService.logoutAllDevices(userDetails.getUserId());
        return ResponseEntity.ok(ApiResponse.success(null, "Đã đăng xuất tất cả thiết bị"));
    }

    // ── Duyệt tài khoản — chỉ MANAGER+ ──────────────────────

    @Operation(summary = "Danh sách tài khoản chờ duyệt")
    @GetMapping("/pending")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<ApiResponse<Page<UserResponse>>> getPendingUsers(
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(authService.getPendingUsers(pageable)));
    }

    @Operation(summary = "Duyệt hoặc từ chối tài khoản")
    @PutMapping("/pending/{userId}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<ApiResponse<UserResponse>> processApproval(
            @PathVariable UUID userId,
            @Valid @RequestBody ApproveUserRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                authService.processUserApproval(userId, request, userDetails.getUserId())));
    }

    @Operation(summary = "Xoá tài khoản nhân viên — soft delete")
    @DeleteMapping("/users/{userId}")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<Void>> deleteUser(
            @PathVariable UUID userId,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        authService.deleteUser(userId, userDetails.getUserId());
        return ResponseEntity.ok(ApiResponse.success(null, "Xoá tài khoản thành công"));
    }
}
