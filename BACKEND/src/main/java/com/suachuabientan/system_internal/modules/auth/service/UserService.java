package com.suachuabientan.system_internal.modules.auth.service;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.auth.dto.request.LoginRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.UserCreationRequest;
import com.suachuabientan.system_internal.modules.auth.dto.response.LoginResponse;
import com.suachuabientan.system_internal.modules.auth.dto.response.UserResponse;
import jakarta.servlet.http.HttpServletRequest;

import java.util.List;

public interface UserService {
    LoginResponse login(LoginRequest loginRequest);
    boolean logout(HttpServletRequest request);
    UserResponse createEmployee(UserCreationRequest request);
}
