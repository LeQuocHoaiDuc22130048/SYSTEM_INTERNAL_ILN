package com.suachuabientan.system_internal.modules.auth.service;

import lombok.AccessLevel;
import lombok.RequiredArgsConstructor;
import lombok.experimental.FieldDefaults;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.util.concurrent.TimeUnit;

@Service
@RequiredArgsConstructor
@FieldDefaults(level = AccessLevel.PRIVATE, makeFinal = true)
public class BlacklistService {
    StringRedisTemplate  stringRedisTemplate;

    public void blacklistToken(String token, long expirationTimeMs) {
        stringRedisTemplate.opsForValue().set(
                "blacklist:" + token,
                "logout",
                expirationTimeMs,
                TimeUnit.MILLISECONDS
        );
    }

    public boolean isBlacklisted(String token) {
        return stringRedisTemplate.hasKey("blacklist:" + token);
    }
}
