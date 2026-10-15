package com.suachuabientan.system_internal.security;

import com.suachuabientan.system_internal.common.util.JwtUtil;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.enums.UserStatus;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import com.suachuabientan.system_internal.security.model.WebSocketUserAuthentication;
import com.suachuabientan.system_internal.security.service.UserDetailsServiceImpl;
import com.suachuabientan.system_internal.security.websocket.JwtStompChannelInterceptor;
import org.junit.jupiter.api.Test;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.security.access.AccessDeniedException;
import java.util.Set;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class JwtStompPermissionTest {
    @Test void revocationAlsoStopsDeliveryOnExistingSubscriptions() {
        var users = mock(UserDetailsServiceImpl.class);
        var jwt = mock(JwtUtil.class);
        var interceptor = new JwtStompChannelInterceptor(jwt, users);
        UserEntity user = new UserEntity();
        user.setId(java.util.UUID.randomUUID()); user.setUsername("employee");
        user.setRole(UserRole.EMPLOYEE); user.setStatus(UserStatus.ACTIVE);
        var granted = new CustomUserDetails(user, Set.of(), Set.of("MESSAGING_USE"));
        when(jwt.isTokenValid("token")).thenReturn(true);
        when(jwt.isAccessToken("token")).thenReturn(true);
        when(jwt.extractUsername("token")).thenReturn("employee");
        when(users.loadUserByUsername("employee")).thenReturn(granted, granted, new CustomUserDetails(user));
        var connect = StompHeaderAccessor.create(StompCommand.CONNECT);
        connect.setSessionId("session-1"); connect.setNativeHeader("Authorization", "Bearer token");
        connect.setLeaveMutable(true);
        interceptor.preSend(MessageBuilder.createMessage(new byte[0], connect.getMessageHeaders()), mock(org.springframework.messaging.MessageChannel.class));
        var outgoing = org.springframework.messaging.simp.SimpMessageHeaderAccessor.create(org.springframework.messaging.simp.SimpMessageType.MESSAGE);
        outgoing.setSessionId("session-1"); outgoing.setDestination("/topic/chat.1");
        var message = MessageBuilder.createMessage(new byte[0], outgoing.getMessageHeaders());
        assertNotNull(interceptor.filterOutbound(message));
        assertNull(interceptor.filterOutbound(message));
    }

    @Test void revokedChatPermissionStopsAnAlreadyConnectedUserSending() {
        var users = mock(UserDetailsServiceImpl.class);
        var interceptor = new JwtStompChannelInterceptor(mock(JwtUtil.class), users);
        UserEntity user = new UserEntity();
        user.setId(java.util.UUID.randomUUID()); user.setUsername("employee");
        user.setRole(UserRole.EMPLOYEE); user.setStatus(UserStatus.ACTIVE);
        var oldDetails = new CustomUserDetails(user, Set.of(), Set.of("MESSAGING_USE"));
        when(users.loadUserByUsername("employee")).thenReturn(new CustomUserDetails(user));
        var headers = StompHeaderAccessor.create(StompCommand.SEND);
        headers.setUser(new WebSocketUserAuthentication(oldDetails));
        headers.setDestination("/app/chat.send");
        var message = MessageBuilder.createMessage(new byte[0], headers.getMessageHeaders());
        assertThrows(AccessDeniedException.class, () -> interceptor.preSend(message, mock(org.springframework.messaging.MessageChannel.class)));
    }
}
