package com.suachuabientan.system_internal.modules.auth.service;

import com.suachuabientan.system_internal.modules.auth.repository.RefreshTokenRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

@Slf4j
@Component
@RequiredArgsConstructor
public class TokenCleanupJob {
    private final RefreshTokenRepository refreshTokenRepository;

    @Scheduled(cron = "0 0 2 * * * *") // 2:00 AM mỗi ngày
    @Transactional
    public void cleanExpiredTokens() {
        log.info("TokenCleanupJob: Bắt đầu xóa refresh token hết hạn...");
        refreshTokenRepository.deleteExpiredAndRevoked(Instant.now());
        log.info("TokenCleanupJob: Hoàn tất xóa refresh token hết hạn.");
    }
}
