package com.suachuabientan.system_internal.modules.auth.service;

import com.suachuabientan.system_internal.common.enums.UserRole;
import com.suachuabientan.system_internal.common.enums.UserStatus;
import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.util.JwtUtil;
import com.suachuabientan.system_internal.modules.auth.domain.UserEntity;
import com.suachuabientan.system_internal.modules.auth.dto.request.RegisterRequest;
import com.suachuabientan.system_internal.modules.auth.dto.response.UserResponse;
import com.suachuabientan.system_internal.modules.auth.mapper.UserMapper;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final AuthenticationManager authenticationManager;
    private final UserMapper userMapper;

    /*
     * Đăng ký tài khoản mới — trạng thái PENDING_APPROVAL, chưa được login (SEC-03).
     */

    @Transactional
    public UserResponse register(RegisterRequest request) {
        if (userRepository.existsByUsernameAndIsDeletedFalse(request.username())) {
            throw new BusinessException("Tên đăng nhập " + request.username() + "' đã tồn tại", 409);
        }
        if (userRepository.existsByEmailAndIsDeletedFalse(request.email())) {
            throw new BusinessException("Email '" + request.email() + "' đã được sử dụng", 409);
        }

        UserEntity user = UserEntity.builder()
                .username(request.username())
                .email(request.email().toLowerCase())
                .passwordHash(passwordEncoder.encode(request.password()))
                .fullName(request.fullName())
                .department(request.department())
                .phone(request.phone())
                .role(UserRole.EMPLOYEE)
                .status(UserStatus.PENDING_APPROVAL)
                .faceEnrolled(false)
                .build();

        UserEntity saved = userRepository.save(user);
        log.info("Tài khoản mới đăng ký: username={}, email={}", saved.getUsername(), saved.getEmail());

        return userMapper.toResponse(saved);
    }
}
