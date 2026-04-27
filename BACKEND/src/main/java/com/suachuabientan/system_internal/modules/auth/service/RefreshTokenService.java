package com.suachuabientan.system_internal.modules.auth.service;

import com.suachuabientan.system_internal.common.exception.AppException;
import com.suachuabientan.system_internal.common.enums.ErrorCode;
import com.suachuabientan.system_internal.modules.auth.domain.RefreshToken;
import com.suachuabientan.system_internal.modules.auth.domain.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.RefreshTokenRepository;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.auth.security.JwtTokenProvider;
import lombok.AccessLevel;
import lombok.RequiredArgsConstructor;
import lombok.experimental.FieldDefaults;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@FieldDefaults(level = AccessLevel.PRIVATE, makeFinal = true)
public class RefreshTokenService {

    RefreshTokenRepository refreshTokenRepository;
    UserRepository userRepository;
    JwtTokenProvider jwtTokenProvider;

    @Value("${app.jwt.refresh-expiration-ms}")
    Long refreshTokenDurationMs;

    /**
     * Tạo refresh token mới cho user
     */
    @Transactional
    public RefreshToken createRefreshToken( String userId) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        // Xóa các refresh token cũ của user (chỉ giữ 1 token active)
        refreshTokenRepository.deleteByUser_Id(userId);

        String token = UUID.randomUUID().toString();
        LocalDateTime expiryDate = LocalDateTime.now().plusNanos(refreshTokenDurationMs * 1_000_000);

        RefreshToken refreshToken = RefreshToken.builder()
                .token(token)
                .user(user)
                .expiryDate(expiryDate)
                .revoked(false)
                .expired(false)
                .build();

        return refreshTokenRepository.save(refreshToken);
    }

    /**
     * Tìm refresh token theo token string
     */
    public RefreshToken findByToken(String token) {
        return refreshTokenRepository.findByToken(token)
                .orElseThrow(() -> new AppException(ErrorCode.INVALID_REFRESH_TOKEN));
    }

    /**
     * Xác thực refresh token
     */
    public RefreshToken verifyExpiration(RefreshToken token) {
        if (token.isExpired() || token.isRevoked()) {
            refreshTokenRepository.delete(token);
            throw new AppException(ErrorCode.REFRESH_TOKEN_EXPIRED);
        }

        if (token.getExpiryDate().isBefore(LocalDateTime.now())) {
            token.setExpired(true);
            refreshTokenRepository.save(token);
            throw new AppException(ErrorCode.REFRESH_TOKEN_EXPIRED);
        }

        return token;
    }

    /**
     * Refresh access token
     */
    @Transactional
    public String refreshToken(String refreshToken) {
        RefreshToken token = findByToken(refreshToken);
        verifyExpiration(token);

        // Tạo access token mới
        UserEntity user = token.getUser();
        return jwtTokenProvider.generateToken(user.getUsername());
    }

    /**
     * Revoke refresh token
     */
    @Transactional
    public void revokeRefreshToken(String token) {
        RefreshToken refreshToken = findByToken(token);
        refreshToken.setRevoked(true);
        refreshTokenRepository.save(refreshToken);
    }

    /**
     * Xóa refresh token
     */
    @Transactional
    public void deleteRefreshToken(String token) {
        refreshTokenRepository.deleteByToken(token);
    }

    /**
     * Xóa tất cả refresh token của user
     */
    @Transactional
    public void deleteByUserId(String userId) {
        refreshTokenRepository.deleteByUser_Id(userId);
    }
}