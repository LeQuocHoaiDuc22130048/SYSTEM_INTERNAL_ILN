package com.suachuabientan.system_internal.modules.auth.service.implement;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.common.enums.BusinessStatus;
import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.enums.ErrorCode;
import com.suachuabientan.system_internal.modules.auth.domain.UserEntity;
import com.suachuabientan.system_internal.modules.auth.dto.request.LoginRequest;
import com.suachuabientan.system_internal.modules.auth.dto.response.LoginResponse;
import com.suachuabientan.system_internal.modules.auth.mapper.UserMapper;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.auth.security.JwtTokenProvider;
import com.suachuabientan.system_internal.modules.auth.service.BlacklistService;
import com.suachuabientan.system_internal.modules.auth.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.experimental.FieldDefaults;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.context.SecurityContextHolder;
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

    @Override
    public LoginResponse login(LoginRequest loginRequest) {
        try {
            Authentication authentication = authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(loginRequest.getUsername(), loginRequest.getPassword())
            );

            SecurityContextHolder.getContext().setAuthentication(authentication);

            UserEntity user = userRepository.findByUsername(loginRequest.getUsername()).orElseThrow(() -> new BusinessException(ErrorCode.UNAUTHORIZED));

            String jwt = tokenProvider.generateToken(user.getUsername());

            LoginResponse response = userMapper.toLoginResponse(user);

            response.setAccessToken(jwt);

            return response;

        } catch (BadCredentialsException e) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        } catch (DisabledException e) {
            throw new BusinessException(ErrorCode.AUTH_002);
        } catch (Exception e) {
            throw new BusinessException(ErrorCode.SYSTEM_ERROR);
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
}
