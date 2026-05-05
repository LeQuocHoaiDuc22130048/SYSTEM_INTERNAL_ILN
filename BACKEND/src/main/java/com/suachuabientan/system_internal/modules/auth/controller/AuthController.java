package com.suachuabientan.system_internal.modules.auth.controller;


import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.auth.dto.request.ApproveUserRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.LoginRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.RefreshTokenRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.RegisterRequest;
import com.suachuabientan.system_internal.modules.auth.dto.response.LoginResponse;
import com.suachuabientan.system_internal.modules.auth.dto.response.UserResponse;
import com.suachuabientan.system_internal.modules.auth.service.AuthService;
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

    @Operation(summary = "Đăng ký tài khoản mới")
    @PostMapping("/register")
    public ResponseEntity<ApiResponse<UserResponse>> register(
            @Valid @RequestBody RegisterRequest request) {
        return ResponseEntity.status(201)
                .body(ApiResponse.created(authService.register(request)));
    }

    @Operation(summary = "Đăng nhập")
    @PostMapping("/login")
    public ResponseEntity<ApiResponse<LoginResponse>> login(@Valid @RequestBody LoginRequest request) {
        return ResponseEntity.ok(ApiResponse.success(authService.login(request)));
    }

    @Operation(summary = "Làm mới access Token")
    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<LoginResponse>> refreshToken(@Valid @RequestBody RefreshTokenRequest request) {
        return ResponseEntity.ok(ApiResponse.success(authService.refreshToken(request)));
    }

    @Operation(summary = "Đăng xuất thiết bị hiện tại")
    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<Void>> logout(@Valid @RequestBody RefreshTokenRequest request) {
        authService.logout(request.refreshToken());
        return ResponseEntity.ok(ApiResponse.success(null, "Đăng xuất thành công"));
    }

    @Operation(summary = "Đăng xuất tất cả thiết bị")
    @PostMapping("/logout-all")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<ApiResponse<Void>> logoutAll(
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID userId = extractUserId(userDetails);
        authService.logoutAllDevices(userId);
        return ResponseEntity.ok(ApiResponse.success(null, "Đã đăng xuất tất cả thiết bị"));
    }

    // ── Authenticated endpoints ───────────────────────────────────────────

    @Operation(summary = "Thông tin tài khoản hiện tại")
    @GetMapping("/me")
    public ResponseEntity<ApiResponse<UserResponse>> getCurrentUser(
            @AuthenticationPrincipal UserDetails userDetails) {
        UserResponse user = authService.searchUsers(userDetails.getUsername(),
                        Pageable.ofSize(1)).getContent().stream().findFirst()
                .orElseThrow();
        return ResponseEntity.ok(ApiResponse.success(user));
    }

    @Operation(summary = "Danh sách tài khoản chờ duyệt")
    @GetMapping("/users/pending")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<ApiResponse<Page<UserResponse>>> getPendingUsers(
            @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.ASC) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(authService.getPendingUsers(pageable)));
    }

    @Operation(summary = "Duyệt hoặc từ chối tài khoản nhân viên")
    @PutMapping("/users/{userId}/approval")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<ApiResponse<UserResponse>> processApproval(
            @PathVariable UUID userId,
            @Valid @RequestBody ApproveUserRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID reviewerId = extractUserId(userDetails);
        return ResponseEntity.ok(ApiResponse.success(
                authService.processUserApproval(userId, request, reviewerId)));
    }

    @Operation(summary = "Tìm kiếm nhân viên")
    @GetMapping("/users")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<ApiResponse<Page<UserResponse>>> searchUsers(
            @RequestParam(required = false) String keyword,
            @PageableDefault(size = 20, sort = "fullName") Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(authService.searchUsers(keyword, pageable)));
    }

    @Operation(summary = "Chi tiết nhân viên")
    @GetMapping("/users/{userId}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN') or #userId == authentication.principal.id")
    public ResponseEntity<ApiResponse<UserResponse>> getUserById(@PathVariable UUID userId) {
        return ResponseEntity.ok(ApiResponse.success(authService.getUserById(userId)));
    }


    @Operation(summary = "Khoá tài khoản nhân viên")
    @PatchMapping("/users/{userId}/suspend")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<ApiResponse<UserResponse>> suspendUser(
            @PathVariable UUID userId,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID performerId = extractUserId(userDetails);
        return ResponseEntity.ok(ApiResponse.success(authService.suspendUser(userId, performerId)));
    }

    @Operation(summary = "Xoá tài khoản nhân viên (soft delete)")
    @DeleteMapping("/users/{userId}")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<Void>> deleteUser(
            @PathVariable UUID userId,
            @AuthenticationPrincipal UserDetails userDetails) {
        UUID performerId = extractUserId(userDetails);
        authService.deleteUser(userId, performerId);
        return ResponseEntity.ok(ApiResponse.success(null, "Xoá tài khoản thành công"));
    }
    // ── Helper ────────────────────────────────────────────────────────────

    /**
     * Lấy UUID từ UserDetails — tạm thời lookup theo username.
     * Sẽ được refactor khi tích hợp CustomUserDetails.
     */
    private UUID extractUserId(UserDetails userDetails) {
        return authService.searchUsers(userDetails.getUsername(), Pageable.ofSize(1))
                .getContent().stream().findFirst()
                .map(UserResponse::id)
                .orElseThrow();
    }
}