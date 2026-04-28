package com.suachuabientan.system_internal.modules.auth.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.auth.dto.request.LoginRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.RefreshTokenRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.UserCreationRequest;
import com.suachuabientan.system_internal.modules.auth.dto.response.LoginResponse;
import com.suachuabientan.system_internal.modules.auth.dto.response.RefreshTokenResponse;
import com.suachuabientan.system_internal.modules.auth.dto.response.UserResponse;
import com.suachuabientan.system_internal.modules.auth.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.experimental.FieldDefaults;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1")
@FieldDefaults(level = lombok.AccessLevel.PRIVATE, makeFinal = true)
@RequiredArgsConstructor
public class UserController {
    UserService userService;

    @PostMapping("/auth/login")
    public ApiResponse<LoginResponse> login(@Valid @RequestBody LoginRequest loginRequest) {
        return ApiResponse.<LoginResponse>builder()
                .message("Đăng nhập thành công")
                .data(userService.login(loginRequest))
                .build();
    }

    @PostMapping("/auth/logout")
    public ApiResponse<Boolean> logout(HttpServletRequest request) {
        boolean isLogout = userService.logout(request);
        return ApiResponse.<Boolean>builder()
                .message(isLogout ? "Đăng xuất thành công" : "Đăng xuất thất bại")
                .data(isLogout)
                .build();
    }

    @PostMapping("/auth/refresh-token")
    public ApiResponse<RefreshTokenResponse> refreshToken(@Valid @RequestBody RefreshTokenRequest request) {
        return ApiResponse.<RefreshTokenResponse>builder()
                .message("Refresh token thành công")
                .data(userService.refreshToken(request))
                .build();
    }

    @PostMapping("/create_user")
    public ApiResponse<UserResponse> createUser(@Valid @RequestBody UserCreationRequest request) {
        return ApiResponse.<UserResponse>builder()
                .message("Tạo nhân viên thành công")
                .data(userService.createEmployee(request))
                .build();
    }
}
