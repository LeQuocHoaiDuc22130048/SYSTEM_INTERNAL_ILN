package com.suachuabientan.system_internal.security.websocket;

import com.suachuabientan.system_internal.common.util.JwtUtil;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import com.suachuabientan.system_internal.security.model.WebSocketUserAuthentication;
import com.suachuabientan.system_internal.security.service.UserDetailsServiceImpl;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

@Slf4j
@Component
@RequiredArgsConstructor
public class JwtStompChannelInterceptor implements ChannelInterceptor {
    private final JwtUtil jwtUtil;
    private final UserDetailsServiceImpl userDetailsService;

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
        if (accessor == null || accessor.getCommand() == null) {
            return message;
        }

        if (StompCommand.CONNECT.equals(accessor.getCommand())) {
            authenticateConnect(accessor);
        }

        return message;
    }

    private void authenticateConnect(StompHeaderAccessor accessor) {
        String token = extractToken(accessor);
        if (!StringUtils.hasText(token) || !jwtUtil.isTokenValid(token) || !jwtUtil.isAccessToken(token)) {
            throw new AccessDeniedException("WebSocket JWT khong hop le");
        }

        String username = jwtUtil.extractUsername(token);
        CustomUserDetails userDetails = (CustomUserDetails) userDetailsService.loadUserByUsername(username);
        if (!userDetails.isAccountNonLocked()) {
            throw new AccessDeniedException("Tai khoan khong duoc phep ket noi WebSocket");
        }

        WebSocketUserAuthentication authentication = new WebSocketUserAuthentication(userDetails);
        accessor.setUser(authentication);
        SecurityContextHolder.getContext().setAuthentication(authentication);
        log.debug("WebSocket authenticated: userId={}, username={}", userDetails.getUserId(), userDetails.getUsername());
    }

    private String extractToken(StompHeaderAccessor accessor) {
        String bearerToken = accessor.getFirstNativeHeader("Authorization");
        if (!StringUtils.hasText(bearerToken)) {
            bearerToken = accessor.getFirstNativeHeader("authorization");
        }
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }

        String accessToken = accessor.getFirstNativeHeader("access_token");
        if (StringUtils.hasText(accessToken)) {
            return accessToken;
        }

        return null;
    }
}
