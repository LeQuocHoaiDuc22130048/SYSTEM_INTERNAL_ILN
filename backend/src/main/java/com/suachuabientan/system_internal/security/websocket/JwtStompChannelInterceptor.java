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
    private final java.util.Map<String, String> sessionUsers = new java.util.concurrent.ConcurrentHashMap<>();

    @org.springframework.context.event.EventListener
    public void onDisconnect(org.springframework.web.socket.messaging.SessionDisconnectEvent event) {
        sessionUsers.remove(event.getSessionId());
    }

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
        if (accessor == null || accessor.getCommand() == null) {
            return message;
        }

        if (StompCommand.CONNECT.equals(accessor.getCommand())) {
            authenticateConnect(accessor);
        }
        if (StompCommand.DISCONNECT.equals(accessor.getCommand()) && accessor.getSessionId() != null) {
            sessionUsers.remove(accessor.getSessionId());
        }
        if (StompCommand.SEND.equals(accessor.getCommand()) || StompCommand.SUBSCRIBE.equals(accessor.getCommand())) {
            if (!(accessor.getUser() instanceof org.springframework.security.core.Authentication authentication)
                    || !(authentication.getPrincipal() instanceof CustomUserDetails previous)) {
                throw new AccessDeniedException("WebSocket authentication required");
            }
            CustomUserDetails current = (CustomUserDetails) userDetailsService.loadUserByUsername(previous.getUsername());
            String destination = accessor.getDestination();
            String permission = destination != null && destination.contains("notification") ? "NOTIFICATION_VIEW" : "MESSAGING_USE";
            if (!current.isAccountNonLocked() || !current.hasPermission(permission)
                    || (StompCommand.SEND.equals(accessor.getCommand()) && !current.hasPermission("MESSAGE_SEND"))) {
                throw new AccessDeniedException("WebSocket permission revoked");
            }
            WebSocketUserAuthentication refreshed = new WebSocketUserAuthentication(current);
            accessor.setUser(refreshed);
            SecurityContextHolder.getContext().setAuthentication(refreshed);
        }

        return message;
    }

    public Message<?> filterOutbound(Message<?> message) {
        var headers = org.springframework.messaging.simp.SimpMessageHeaderAccessor.wrap(message);
        String destination = headers.getDestination();
        if (destination == null) return message;
        String sessionId = headers.getSessionId();
        String username = sessionId == null ? null : sessionUsers.get(sessionId);
        if (username == null) return null;
        try {
            CustomUserDetails current = (CustomUserDetails) userDetailsService.loadUserByUsername(username);
            String permission = destination.contains("notification") ? "NOTIFICATION_VIEW" : "MESSAGING_USE";
            return current.isAccountNonLocked() && current.hasPermission(permission) ? message : null;
        } catch (org.springframework.security.core.userdetails.UsernameNotFoundException ex) {
            return null;
        }
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
        if (accessor.getSessionId() != null) sessionUsers.put(accessor.getSessionId(), username);
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
