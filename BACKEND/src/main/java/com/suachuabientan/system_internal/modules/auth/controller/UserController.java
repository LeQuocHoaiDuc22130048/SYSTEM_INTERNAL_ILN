package com.suachuabientan.system_internal.modules.auth.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.auth.dto.UserResponse;
import com.suachuabientan.system_internal.modules.auth.service.UserService;
import lombok.RequiredArgsConstructor;
import lombok.experimental.FieldDefaults;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/auth")
@FieldDefaults(level = lombok.AccessLevel.PRIVATE, makeFinal = true)
@RequiredArgsConstructor
public class UserController {
    UserService  userService;

    @GetMapping("/users")
    public ApiResponse<List<UserResponse>> getAll() {
        List<UserResponse> list = userService.getAllUsers();
        return ApiResponse.success(list, "Lấy danh sách thành công");
    }
}
