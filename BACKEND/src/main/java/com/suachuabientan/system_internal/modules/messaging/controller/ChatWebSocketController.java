package com.suachuabientan.system_internal.modules.messaging.controller;

import com.suachuabientan.system_internal.modules.messaging.dto.request.SendMessageWSRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.response.MessageResponse;
import com.suachuabientan.system_internal.modules.messaging.service.MessagingService;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.simp.annotation.SendToUser;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.stereotype.Controller;

@Controller
@RequiredArgsConstructor
public class ChatWebSocketController {
    private final MessagingService messagingService;

    @MessageMapping("/messages.send")
    @SendToUser("/queue/messages")
    public MessageResponse send(
            @Valid SendMessageWSRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return messagingService.sendMessage(request, userDetails.getUserId());
    }
}
