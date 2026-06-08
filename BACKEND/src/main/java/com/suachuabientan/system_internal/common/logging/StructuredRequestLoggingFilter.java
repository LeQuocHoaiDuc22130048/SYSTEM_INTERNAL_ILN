package com.suachuabientan.system_internal.common.logging;

import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.lang.NonNull;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.UUID;

@Slf4j
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class StructuredRequestLoggingFilter extends OncePerRequestFilter {
    private static final String REQUEST_ID_HEADER = "X-Request-Id";
    private static final String CORRELATION_ID_HEADER = "X-Correlation-Id";

    @Override
    protected void doFilterInternal(
            @NonNull HttpServletRequest request,
            @NonNull HttpServletResponse response,
            @NonNull FilterChain filterChain) throws ServletException, IOException {
        long startedAt = System.nanoTime();
        String requestId = requestId(request);
        MDC.put("request_id", requestId);
        MDC.put("method", request.getMethod());
        MDC.put("path", request.getRequestURI());
        MDC.put("client_ip", clientIp(request));
        response.setHeader(REQUEST_ID_HEADER, requestId);
        response.setHeader(CORRELATION_ID_HEADER, requestId);

        try {
            filterChain.doFilter(request, response);
        } finally {
            long latencyMs = (System.nanoTime() - startedAt) / 1_000_000;
            MDC.put("status_code", Integer.toString(response.getStatus()));
            MDC.put("latency_ms", Long.toString(latencyMs));
            putAuthenticatedUser();
            if (response.getStatus() >= 500) {
                log.error("http_request result=ERROR");
            } else if (response.getStatus() >= 400) {
                log.warn("http_request result=WARNING");
            } else {
                log.info("http_request result=OK");
            }
            MDC.clear();
        }
    }

    private String requestId(HttpServletRequest request) {
        String incoming = request.getHeader(REQUEST_ID_HEADER);
        if (!StringUtils.hasText(incoming)) {
            incoming = request.getHeader(CORRELATION_ID_HEADER);
        }
        return StringUtils.hasText(incoming) ? incoming : UUID.randomUUID().toString();
    }

    private String clientIp(HttpServletRequest request) {
        String forwardedFor = request.getHeader("X-Forwarded-For");
        if (StringUtils.hasText(forwardedFor)) {
            return forwardedFor.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }

    private void putAuthenticatedUser() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || authentication.getPrincipal() == null) return;
        Object principal = authentication.getPrincipal();
        if (principal instanceof CustomUserDetails userDetails) {
            MDC.put("user_id", userDetails.getUserId().toString());
            MDC.put("user_role", userDetails.getRole());
        }
    }
}
