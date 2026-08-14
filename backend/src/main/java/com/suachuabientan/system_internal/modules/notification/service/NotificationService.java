package com.suachuabientan.system_internal.modules.notification.service;

import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.enums.UserStatus;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.notification.dto.response.NotificationResponse;
import com.suachuabientan.system_internal.modules.notification.entity.Notification;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import com.suachuabientan.system_internal.modules.notification.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationService {
    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;
    private final FcmService fcmService;
    private final SimpMessagingTemplate messagingTemplate;

    @Transactional(readOnly = true)
    public Page<NotificationResponse> getMyNotifications(UUID recipientId, Pageable pageable) {
        return notificationRepository.findByRecipient(recipientId, pageable)
                .map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public long countUnread(UUID recipientId) {
        return notificationRepository.countUnread(recipientId);
    }

    @Transactional
    public NotificationResponse markAsRead(UUID notificationId, UUID recipientId) {
        Notification notification = notificationRepository
                .findByIdAndRecipientIdAndIsDeletedFalse(notificationId, recipientId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy thông báo: " + notificationId));

        notification.setIsRead(true);
        return toResponse(notificationRepository.save(notification));
    }

    @Transactional
    public long markAllAsRead(UUID recipientId) {
        long unreadBeforeUpdate = notificationRepository.countUnread(recipientId);
        notificationRepository.markAllAsRead(recipientId);
        return unreadBeforeUpdate;
    }

    @Transactional
    public void updateDeviceToken(UUID userId, String deviceToken) {
        UserEntity user = userRepository.findByIdAndIsDeletedFalse(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng: " + userId));
        user.setDeviceToken(deviceToken);
        userRepository.save(user);
    }

    @Transactional
    public void clearDeviceToken(UUID userId) {
        UserEntity user = userRepository.findByIdAndIsDeletedFalse(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng: " + userId));
        user.setDeviceToken(null);
        userRepository.save(user);
    }

    @Transactional
    public NotificationResponse sendToUser(
            UUID recipientId,
            NotificationType type,
            String title,
            String body,
            String refType,
            String refId,
            boolean pushEnabled) {
        UserEntity recipient = userRepository.findByIdAndIsDeletedFalse(recipientId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người nhận: " + recipientId));

        Notification notification = Notification.builder()
                .recipientId(recipientId)
                .type(type)
                .title(title)
                .body(body)
                .refType(refType)
                .refId(refId)
                .isRead(false)
                .build();

        Notification saved = notificationRepository.save(notification);
        NotificationResponse response = toResponse(saved);
        publishInApp(response);

        if (pushEnabled && StringUtils.hasText(recipient.getDeviceToken())) {
            fcmService.sendToDevice(
                    recipient.getDeviceToken(),
                    title,
                    body,
                    Map.of(
                            "notificationId", saved.getId().toString(),
                            "type", type.name(),
                            "refType", refType == null ? "" : refType,
                            "refId", refId == null ? "" : refId
                    ));
        }

        return response;
    }

    @Transactional
    public List<NotificationResponse> sendToUsers(
            Collection<UUID> recipientIds,
            NotificationType type,
            String title,
            String body,
            String refType,
            String refId,
            boolean pushEnabled) {
        return recipientIds.stream()
                .distinct()
                .map(recipientId -> sendToUser(recipientId, type, title, body, refType, refId, pushEnabled))
                .toList();
    }

    @Transactional
    public List<NotificationResponse> sendToRoles(
            Collection<UserRole> roles,
            NotificationType type,
            String title,
            String body,
            String refType,
            String refId,
            boolean pushEnabled) {
        List<UUID> recipientIds = userRepository
                .findByRoleInAndStatusAndIsDeletedFalse(roles, UserStatus.ACTIVE)
                .stream()
                .map(UserEntity::getId)
                .toList();

        return sendToUsers(recipientIds, type, title, body, refType, refId, pushEnabled);
    }

    private void publishInApp(NotificationResponse response) {
        messagingTemplate.convertAndSendToUser(
                response.recipientId().toString(),
                "/queue/notifications",
                response);
    }

    private NotificationResponse toResponse(Notification notification) {
        return new NotificationResponse(
                notification.getId(),
                notification.getRecipientId(),
                notification.getType().name(),
                notification.getTitle(),
                notification.getBody(),
                notification.getRefType(),
                notification.getRefId(),
                notification.getIsRead(),
                notification.getCreatedAt()
        );
    }
}
