package com.suachuabientan.system_internal.modules.messaging.service;

import com.suachuabientan.system_internal.modules.messaging.dto.response.MessageResponse;
import com.suachuabientan.system_internal.modules.messaging.repository.ConversationMemberRepository;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

@Component
@RequiredArgsConstructor
public class MessagingRealtimePublisher {
    private final SimpMessagingTemplate messagingTemplate;
    private final ConversationMemberRepository conversationMemberRepository;
    private final NotificationService notificationService;

    public void publishConversationEvent(UUID conversationId, String type, Object payload) {
        messagingTemplate.convertAndSend(
                "/topic/conversation/" + conversationId + "/events",
                Map.of(
                        "type", type,
                        "conversationId", conversationId,
                        "payload", payload,
                        "timestamp", Instant.now().toString()));
    }

    public void publishMessage(MessageResponse response, UUID senderId) {
        messagingTemplate.convertAndSend(
                "/topic/conversation/" + response.conversationId(),
                response);

        conversationMemberRepository.findByConversationId(response.conversationId())
                .stream()
                .filter(member -> !member.getUserId().equals(senderId))
                .forEach(member -> messagingTemplate.convertAndSendToUser(
                        member.getUserId().toString(),
                        "/queue/messages",
                        response));
    }

    public void notifyMembers(MessageResponse response, UUID senderId) {
        conversationMemberRepository.findByConversationId(response.conversationId())
                .stream()
                .filter(member -> !member.getUserId().equals(senderId))
                .filter(member -> !Boolean.TRUE.equals(member.getNotificationsMuted()))
                .forEach(member -> notificationService.sendToUser(
                        member.getUserId(),
                        NotificationType.NEW_MESSAGE,
                        "Tin nh\u1EAFn m\u1EDBi",
                        response.contentPreview(),
                        "CONVERSATION",
                        response.conversationId().toString(),
                        true));
    }
}
