package com.suachuabientan.system_internal.modules.auth.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.common.enums.BusinessStatus;
import com.suachuabientan.system_internal.modules.auth.dto.request.LoginRequest;
import com.suachuabientan.system_internal.modules.auth.dto.response.LoginResponse;
import com.suachuabientan.system_internal.modules.auth.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.experimental.FieldDefaults;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth")
@FieldDefaults(level = lombok.AccessLevel.PRIVATE, makeFinal = true)
@RequiredArgsConstructor
public class UserController {
    UserService userService;

    @PostMapping("/login")
    public ApiResponse<LoginResponse> login(@RequestBody LoginRequest loginRequest) {
        return ApiResponse.<LoginResponse>builder()
                .status(BusinessStatus.SUCCESS.name())
                .message("Đăng nhập thành công")
                .data(userService.login(loginRequest))
                .build();
    }

    @PostMapping("/logout")
    public ApiResponse<Boolean> logout(HttpServletRequest request) {
        boolean isLogout = userService.logout(request);
        return ApiResponse.<Boolean>builder()
                .status(isLogout ? BusinessStatus.SUCCESS.name() : BusinessStatus.FAILURE.name())
                .message(isLogout ? "Đăng xuất thành công" : "Đăng xuất thất bại")
                .data(isLogout)
                .build();
    }
}
