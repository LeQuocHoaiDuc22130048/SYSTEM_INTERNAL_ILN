package com.suachuabientan.system_internal.modules.auth.service;

import com.suachuabientan.system_internal.modules.auth.entity.PasswordResetOtp;
import com.suachuabientan.system_internal.modules.auth.repository.PasswordResetOtpRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PasswordResetOtpServiceTest {

    @Mock
    private PasswordResetOtpRepository passwordResetOtpRepository;

    private PasswordResetOtpService passwordResetOtpService;

    @BeforeEach
    void setUp() {
        passwordResetOtpService = new PasswordResetOtpService(passwordResetOtpRepository);
    }

    @Test
    void recordFailedAttempt_IncrementsAttempts_WhenBelowLimit() {
        UUID otpId = UUID.randomUUID();
        PasswordResetOtp otp = PasswordResetOtp.builder()
                .id(otpId)
                .userId(UUID.randomUUID())
                .codeHash("hash")
                .expiresAt(Instant.now().plusSeconds(300))
                .attempts(2)
                .used(false)
                .createdAt(Instant.now())
                .build();

        when(passwordResetOtpRepository.findById(otpId)).thenReturn(Optional.of(otp));

        int result = passwordResetOtpService.recordFailedAttempt(otpId);

        assertEquals(3, result);
        assertEquals(3, otp.getAttempts());
        assertEquals(false, otp.isUsed());
        verify(passwordResetOtpRepository).save(otp);
    }

    @Test
    void recordFailedAttempt_MarksUsedTrue_WhenAttemptsReachFive() {
        UUID otpId = UUID.randomUUID();
        PasswordResetOtp otp = PasswordResetOtp.builder()
                .id(otpId)
                .userId(UUID.randomUUID())
                .codeHash("hash")
                .expiresAt(Instant.now().plusSeconds(300))
                .attempts(4)
                .used(false)
                .createdAt(Instant.now())
                .build();

        when(passwordResetOtpRepository.findById(otpId)).thenReturn(Optional.of(otp));

        int result = passwordResetOtpService.recordFailedAttempt(otpId);

        assertEquals(5, result);
        assertEquals(5, otp.getAttempts());
        assertTrue(otp.isUsed());
        verify(passwordResetOtpRepository).save(otp);
    }

    @Test
    void recordFailedAttempt_ReturnsZero_WhenOtpNotFound() {
        UUID otpId = UUID.randomUUID();
        when(passwordResetOtpRepository.findById(otpId)).thenReturn(Optional.empty());

        int result = passwordResetOtpService.recordFailedAttempt(otpId);

        assertEquals(0, result);
        verify(passwordResetOtpRepository, never()).save(any());
    }
}
