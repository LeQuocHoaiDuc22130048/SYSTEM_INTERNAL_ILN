package com.suachuabientan.system_internal.common.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.AccessLevel;
import lombok.RequiredArgsConstructor;
import lombok.experimental.FieldDefaults;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
@Order(1) // Chạy trước JwtAuthFilter
@RequiredArgsConstructor
@FieldDefaults(level = AccessLevel.PRIVATE, makeFinal = true)
public class RateLimitFilter extends OncePerRequestFilter {

    RateLimiter rateLimiter;

    // Rate limit cho login: tối đa 5 request trong 1 phút
    private static final int LOGIN_MAX_REQUESTS = 5;
    private static final int LOGIN_TIME_WINDOW = 60; // 60 giây

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {

        // Chỉ áp dụng rate limiting cho login endpoint
        if (isLoginRequest(request)) {
            String clientIp = getClientIp(request);
            String rateLimitKey = "login:" + clientIp;

            if (!rateLimiter.tryAcquire(rateLimitKey, LOGIN_MAX_REQUESTS, LOGIN_TIME_WINDOW)) {
                long remainingTime = LOGIN_TIME_WINDOW; // Có thể lấy từ Redis TTL
                long remainingRequests = rateLimiter.getRemainingRequests(rateLimitKey, LOGIN_MAX_REQUESTS);

                response.setStatus(429); // HTTP 429 Too Many Requests
                response.setContentType("application/json");
                response.getWriter().write(String.format(
                        "{\"error\":\"Too many login attempts. Please try again in %d seconds.\",\"remainingRequests\":%d}",
                        remainingTime,
                        remainingRequests
                ));
                return;
            }

            // Thêm rate limit headers
            long remainingRequests = rateLimiter.getRemainingRequests(rateLimitKey, LOGIN_MAX_REQUESTS);
            response.setHeader("X-RateLimit-Limit", String.valueOf(LOGIN_MAX_REQUESTS));
            response.setHeader("X-RateLimit-Remaining", String.valueOf(remainingRequests));
            response.setHeader("X-RateLimit-Reset", String.valueOf(LOGIN_TIME_WINDOW));
        }

        filterChain.doFilter(request, response);
    }

    private boolean isLoginRequest(HttpServletRequest request) {
        String path = request.getRequestURI();
        String method = request.getMethod();
        return "/api/v1/auth/login".equals(path) && "POST".equalsIgnoreCase(method);
    }

    private String getClientIp(HttpServletRequest request) {
        String ip = request.getHeader("X-Forwarded-For");
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("X-Real-IP");
        }
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getRemoteAddr();
        }
        // Nếu có nhiều IP (trong trường hợp proxy), lấy IP đầu tiên
        if (ip != null && ip.contains(",")) {
            ip = ip.split(",")[0].trim();
        }
        return ip;
    }
}