package com.suachuabientan.system_internal.modules.auth.service;

import com.suachuabientan.system_internal.modules.auth.entity.PasswordResetOtp;
import com.suachuabientan.system_internal.modules.auth.repository.PasswordResetOtpRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class PasswordResetOtpService {

    private final PasswordResetOtpRepository passwordResetOtpRepository;

    /**
     * Ghi nhận lượt nhập sai mã OTP trong một transaction độc lập (REQUIRES_NEW)
     * để không bị rollback khi luồng xác thực ném BusinessException.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public int recordFailedAttempt(UUID otpId) {
        if (otpId == null) {
            return 0;
        }

        PasswordResetOtp otp = passwordResetOtpRepository.findById(otpId).orElse(null);
        if (otp == null) {
            return 0;
        }

        int newAttempts = otp.getAttempts() + 1;
        otp.setAttempts(newAttempts);
        if (newAttempts >= 5) {
            otp.setUsed(true);
            log.warn("Password reset OTP locked after reaching maximum attempts: otpId={}, userId={}", otpId, otp.getUserId());
        }

        passwordResetOtpRepository.save(otp);
        log.info("Recorded failed OTP attempt: otpId={}, attempts={}", otpId, newAttempts);
        return newAttempts;
    }
}
