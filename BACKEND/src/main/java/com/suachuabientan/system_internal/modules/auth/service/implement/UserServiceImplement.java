package com.suachuabientan.system_internal.modules.auth.service.implement;

import com.suachuabientan.system_internal.common.exception.AppException;
import com.suachuabientan.system_internal.common.enums.ErrorCode;
import com.suachuabientan.system_internal.modules.auth.domain.RefreshToken;
import com.suachuabientan.system_internal.modules.auth.domain.UserEntity;
import com.suachuabientan.system_internal.modules.auth.dto.request.LoginRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.RefreshTokenRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.UserCreationRequest;
import com.suachuabientan.system_internal.modules.auth.dto.response.LoginResponse;
import com.suachuabientan.system_internal.modules.auth.dto.response.RefreshTokenResponse;
import com.suachuabientan.system_internal.modules.auth.dto.response.UserResponse;
import com.suachuabientan.system_internal.modules.auth.mapper.UserMapper;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.auth.security.JwtTokenProvider;
import com.suachuabientan.system_internal.modules.auth.service.BlacklistService;
import com.suachuabientan.system_internal.modules.auth.service.RefreshTokenService;
import com.suachuabientan.system_internal.modules.auth.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import lombok.experimental.FieldDefaults;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Date;

@Slf4j
@Service
@RequiredArgsConstructor
@FieldDefaults(level = lombok.AccessLevel.PRIVATE, makeFinal = true)
public class UserServiceImplement implements UserService {

    UserRepository userRepository;
    UserMapper userMapper;
    AuthenticationManager authenticationManager;
    JwtTokenProvider tokenProvider;
    BlacklistService blacklistService;
    RefreshTokenService refreshTokenService;
    private final PasswordEncoder passwordEncoder;

    @Override
    public LoginResponse login(LoginRequest loginRequest) {
        try {
            Authentication authentication = authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(loginRequest.getUsername(), loginRequest.getPassword())
            );

            SecurityContextHolder.getContext().setAuthentication(authentication);

            UserEntity user = userRepository.findByUsername(loginRequest.getUsername()).orElseThrow(() -> new AppException(ErrorCode.UNAUTHORIZED));

            String jwt = tokenProvider.generateToken(user.getUsername());

            // Tạo refresh token
            RefreshToken refreshToken = refreshTokenService.createRefreshToken(user.getId());

            LoginResponse response = userMapper.toLoginResponse(user);

            response.setAccessToken(jwt);
            response.setRefreshToken(refreshToken.getToken());

            return response;

        } catch (BadCredentialsException e) {
            throw new AppException(ErrorCode.UNAUTHORIZED);
        } catch (DisabledException e) {
            throw new AppException(ErrorCode.AUTH_002);
        } catch (Exception e) {
            throw new AppException(ErrorCode.SYSTEM_ERROR);
        }
    }

    @Override
    public boolean logout(HttpServletRequest request) {
        try {
            String authHeader = request.getHeader("Authorization");
            if (authHeader != null && authHeader.startsWith("Bearer ")) {
                String jwt = authHeader.substring(7);

                if (tokenProvider.validateToken(jwt)) {
                    Date expirationDate = tokenProvider.getExpirationDateFromToken(jwt);
                    long diffInMs = expirationDate.getTime() - System.currentTimeMillis();
                    if (diffInMs > 0) {
                        blacklistService.blacklistToken(jwt, diffInMs);
                    }
                }

                SecurityContextHolder.clearContext();
                return true;
            }

            return false;
        } catch (Exception e) {
            log.error("Lỗi khi đăng xuất: {}", e.getMessage());
            return false;
        }
    }

    @Override
    public RefreshTokenResponse refreshToken(RefreshTokenRequest request) {
        try {
            // Tìm và xác thực refresh token
            RefreshToken refreshToken = refreshTokenService.findByToken(request.getRefreshToken());
            refreshTokenService.verifyExpiration(refreshToken);

            // Tạo access token mới
            String newAccessToken = tokenProvider.generateToken(refreshToken.getUser().getUsername());

            // Tạo refresh token mới (rotation)
            RefreshToken newRefreshToken = refreshTokenService.createRefreshToken(refreshToken.getUser().getId());

            return RefreshTokenResponse.builder()
                    .accessToken(newAccessToken)
                    .refreshToken(newRefreshToken.getToken())
                    .build();

        } catch (Exception e) {
            log.error("Lỗi khi refresh token: {}", e.getMessage());
            throw new AppException(ErrorCode.INVALID_REFRESH_TOKEN);
        }
    }

    @Override
    @Transactional
    public UserResponse createEmployee(UserCreationRequest request) {
        if (userRepository.existsByUsername(request.getUsername())) throw new AppException(ErrorCode.AUTH_003);

        String password = passwordEncoder.encode(request.getPassword());
        UserEntity newUser = UserEntity.builder()
                .username(request.getUsername())
                .password(password)
                .role(request.getRole())
                .isActive(true)
                .build();

        return userMapper.toResponse(userRepository.save(newUser));
    }
}
