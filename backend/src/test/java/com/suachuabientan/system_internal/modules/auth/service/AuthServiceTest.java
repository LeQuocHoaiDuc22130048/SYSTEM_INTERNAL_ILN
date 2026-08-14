package com.suachuabientan.system_internal.modules.auth.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.util.EmployeeCodeGenerator;
import com.suachuabientan.system_internal.common.util.JwtUtil;
import com.suachuabientan.system_internal.modules.auth.dto.request.ForgotPasswordRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.RequestPasswordResetOtpRequest;
import com.suachuabientan.system_internal.modules.auth.entity.PasswordResetOtp;
import com.suachuabientan.system_internal.modules.auth.entity.RefreshToken;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.mapper.UserMapper;
import com.suachuabientan.system_internal.modules.auth.repository.PasswordResetOtpRepository;
import com.suachuabientan.system_internal.modules.auth.repository.RefreshTokenRepository;
import com.suachuabientan.system_internal.modules.auth.repository.UserRegistrationRequestRepository;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {
    @Mock private UserRepository userRepository;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private UserMapper userMapper;
    @Mock private EmployeeCodeGenerator employeeCodeGenerator;
    @Mock private AuthenticationManager authenticationManager;
    @Mock private JwtUtil jwtUtil;
    @Mock private RefreshTokenRepository refreshTokenRepository;
    @Mock private UserRegistrationRequestRepository userRegistrationRequestRepository;
    @Mock private NotificationService notificationService;
    @Mock private PasswordResetOtpRepository passwordResetOtpRepository;
    @Mock private RbacService rbacService;

    private AuthService authService;
    private UserEntity user;

    @BeforeEach
    void setUp() {
        authService = new AuthService(
                userRepository,
                passwordEncoder,
                userMapper,
                employeeCodeGenerator,
                authenticationManager,
                jwtUtil,
                refreshTokenRepository,
                userRegistrationRequestRepository,
                notificationService,
                passwordResetOtpRepository,
                rbacService);
        user = new UserEntity();
        user.setId(UUID.randomUUID());
        user.setUsername("employee");
        user.setPhone("0123456789");
    }

    @Test
    void requestPasswordResetOtpStoresHashedChallengeAndSendsPush() {
        when(userRepository.findByUsernameAndIsDeletedFalse("employee"))
                .thenReturn(Optional.of(user));
        when(passwordEncoder.encode(anyString())).thenReturn("otp-hash");

        authService.requestPasswordResetOtp(
                new RequestPasswordResetOtpRequest("employee", "0123456789"));

        ArgumentCaptor<PasswordResetOtp> otpCaptor = ArgumentCaptor.forClass(PasswordResetOtp.class);
        verify(passwordResetOtpRepository).invalidateActiveForUser(user.getId());
        verify(passwordResetOtpRepository).save(otpCaptor.capture());
        assertEquals("otp-hash", otpCaptor.getValue().getCodeHash());
        verify(notificationService).sendToUser(
                eq(user.getId()),
                eq(NotificationType.PASSWORD_RESET_OTP),
                eq("Ma xac minh dat lai mat khau"),
                contains("Ma OTP cua ban la"),
                eq("PASSWORD_RESET"),
                eq(user.getId().toString()),
                eq(true));
    }

    @Test
    void forgotPasswordRequiresValidOtpBeforeChangingPassword() {
        when(userRepository.findByUsernameAndIsDeletedFalse("employee"))
                .thenReturn(Optional.of(user));
        PasswordResetOtp otp = PasswordResetOtp.builder()
                .userId(user.getId())
                .codeHash("otp-hash")
                .expiresAt(Instant.now().plusSeconds(300))
                .attempts(0)
                .used(false)
                .createdAt(Instant.now())
                .build();
        when(passwordResetOtpRepository.findFirstByUserIdAndUsedFalseOrderByCreatedAtDesc(user.getId()))
                .thenReturn(Optional.of(otp));
        when(passwordEncoder.matches("123456", "otp-hash")).thenReturn(true);
        when(passwordEncoder.encode("NewPassword123!")).thenReturn("new-hash");

        authService.forgotPassword(new ForgotPasswordRequest(
                "employee", "0123456789", "123456", "NewPassword123!", "NewPassword123!"));

        assertEquals("new-hash", user.getPasswordHash());
        assertEquals(true, otp.isUsed());
        verify(userRepository).save(user);
        verify(refreshTokenRepository).revokeAllByUserId(user.getId());
    }

    @Test
    void forgotPasswordRejectsIncorrectOtpWithoutChangingPassword() {
        when(userRepository.findByUsernameAndIsDeletedFalse("employee"))
                .thenReturn(Optional.of(user));
        PasswordResetOtp otp = PasswordResetOtp.builder()
                .userId(user.getId())
                .codeHash("otp-hash")
                .expiresAt(Instant.now().plusSeconds(300))
                .attempts(0)
                .used(false)
                .createdAt(Instant.now())
                .build();
        when(passwordResetOtpRepository.findFirstByUserIdAndUsedFalseOrderByCreatedAtDesc(user.getId()))
                .thenReturn(Optional.of(otp));
        when(passwordEncoder.matches("000000", "otp-hash")).thenReturn(false);

        assertThrows(BusinessException.class, () -> authService.forgotPassword(
                new ForgotPasswordRequest("employee", "0123456789", "000000",
                        "NewPassword123!", "NewPassword123!")));

        assertEquals(1, otp.getAttempts());
        verify(passwordResetOtpRepository).save(otp);
        verify(userRepository, never()).save(any(UserEntity.class));
    }

    @Test
    void logoutClearsPushDestinationForRevokedSession() {
        UUID userId = UUID.randomUUID();
        RefreshToken refreshToken = RefreshToken.builder()
                .id(UUID.randomUUID())
                .userId(userId)
                .tokenHash("refresh-hash")
                .expiresAt(Instant.now().plusSeconds(300))
                .revoked(false)
                .createdAt(Instant.now())
                .build();
        when(jwtUtil.hashToken("refresh-token")).thenReturn("refresh-hash");
        when(refreshTokenRepository.findByTokenHashAndRevokedFalse("refresh-hash"))
                .thenReturn(Optional.of(refreshToken));

        authService.logout("refresh-token");

        assertEquals(true, refreshToken.isRevoked());
        verify(refreshTokenRepository).save(refreshToken);
        verify(notificationService).clearDeviceToken(userId);
    }

    @Test
    void logoutAllClearsPushDestination() {
        UUID userId = UUID.randomUUID();

        authService.logoutAllDevices(userId);

        verify(refreshTokenRepository).revokeAllByUserId(userId);
        verify(notificationService).clearDeviceToken(userId);
    }
}
