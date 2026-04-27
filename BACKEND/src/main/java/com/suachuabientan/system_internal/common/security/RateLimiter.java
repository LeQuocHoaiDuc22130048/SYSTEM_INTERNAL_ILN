package com.suachuabientan.system_internal.common.security;

import lombok.AccessLevel;
import lombok.RequiredArgsConstructor;
import lombok.experimental.FieldDefaults;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.util.concurrent.TimeUnit;

@Component
@RequiredArgsConstructor
@FieldDefaults(level = AccessLevel.PRIVATE, makeFinal = true)
public class RateLimiter {

    StringRedisTemplate redisTemplate;

    /**
     * Kiểm tra và tăng số lượng request cho một key
     * @param key Key để rate limit (ví dụ: "login:192.168.1.1" hoặc "login:user123")
     * @param maxRequests Số lượng request tối đa
     * @param timeWindow Khoảng thời gian (giây)
     * @return true nếu cho phép request, false nếu vượt quá giới hạn
     */
    public boolean tryAcquire(String key, int maxRequests, int timeWindow) {
        String redisKey = "rate_limit:" + key;
        Long currentCount = redisTemplate.opsForValue().increment(redisKey);

        if (currentCount == null) {
            return false;
        }

        if (currentCount == 1) {
            // Lần đầu tiên, set expiration
            redisTemplate.expire(redisKey, timeWindow, TimeUnit.SECONDS);
        }

        return currentCount <= maxRequests;
    }

    /**
     * Lấy số lượng request còn lại
     * @param key Key để rate limit
     * @param maxRequests Số lượng request tối đa
     * @return Số lượng request còn lại
     */
    public long getRemainingRequests(String key, int maxRequests) {
        String redisKey = "rate_limit:" + key;
        String countStr = redisTemplate.opsForValue().get(redisKey);
        if (countStr == null) {
            return maxRequests;
        }
        long count = Long.parseLong(countStr);
        return Math.max(0, maxRequests - count);
    }

    /**
     * Reset rate limit cho một key
     * @param key Key để reset
     */
    public void reset(String key) {
        String redisKey = "rate_limit:" + key;
        redisTemplate.delete(redisKey);
    }
}