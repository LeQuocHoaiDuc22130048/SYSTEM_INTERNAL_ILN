package com.suachuabientan.system_internal.modules.messaging.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.messaging.dto.request.CreateConversationRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.request.SendMessageRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.request.SendMessageWSRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.request.UpdateConversationRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.response.ConversationResponse;
import com.suachuabientan.system_internal.modules.messaging.dto.response.MessageResponse;
import com.suachuabientan.system_internal.modules.messaging.entity.Conversation;
import com.suachuabientan.system_internal.modules.messaging.entity.ConversationMember;
import com.suachuabientan.system_internal.modules.messaging.entity.Message;
import com.suachuabientan.system_internal.modules.messaging.entity.MessageRead;
import com.suachuabientan.system_internal.modules.messaging.enums.ConversationType;
import com.suachuabientan.system_internal.modules.messaging.enums.MessageType;
import com.suachuabientan.system_internal.modules.messaging.repository.ConversationMemberRepository;
import com.suachuabientan.system_internal.modules.messaging.repository.ConversationRepository;
import com.suachuabientan.system_internal.modules.messaging.repository.MessageReadRepository;
import com.suachuabientan.system_internal.modules.messaging.repository.MessageRepository;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.Instant;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class MessagingService {
    private final ConversationRepository conversationRepository;
    private final ConversationMemberRepository conversationMemberRepository;
    private final MessageRepository messageRepository;
    private final MessageReadRepository messageReadRepository;
    private final UserRepository userRepository;
    private final SimpMessagingTemplate messagingTemplate;
    private final NotificationService notificationService;

    @Transactional(readOnly = true)
    public List<ConversationResponse> getMyConversations(UUID userId) {
        return conversationRepository.findByMember(userId)
                .stream()
                .map(conversation -> toConversationResponse(conversation, userId))
                .toList();
    }

    @Transactional
    public ConversationResponse createConversation(CreateConversationRequest request, UUID creatorId) {
        ConversationType type = parseConversationType(request.type());
        List<UUID> memberIds = normalizeMemberIds(request.memberIds(), creatorId);
        validateConversationRequest(type, request.name(), memberIds, creatorId);

        if (type == ConversationType.DIRECT) {
            UUID otherUserId = memberIds.stream()
                    .filter(memberId -> !memberId.equals(creatorId))
                    .findFirst()
                    .orElseThrow(() -> new BusinessException("Cuoc tro chuyen DIRECT can mot thanh vien khac"));
            Optional<Conversation> existing = conversationRepository.findDirectConversation(creatorId, otherUserId);
            if (existing.isPresent()) {
                return toConversationResponse(existing.get(), creatorId);
            }
        }

        memberIds.forEach(this::findUser);
        Conversation conversation = Conversation.builder()
                .type(type)
                .name(type == ConversationType.GROUP ? request.name() : null)
                .build();
        Conversation saved = conversationRepository.save(conversation);

        List<ConversationMember> members = memberIds.stream()
                .map(memberId -> ConversationMember.builder()
                        .conversationId(saved.getId())
                        .userId(memberId)
                        .joinAt(Instant.now())
                        .lastReadAt(null)
                        .isAdmin(memberId.equals(creatorId))
                        .build())
                .toList();
        conversationMemberRepository.saveAll(members);

        return toConversationResponse(saved, creatorId);
    }

    @Transactional(readOnly = true)
    public Page<MessageResponse> getMessages(UUID conversationId, UUID userId, Pageable pageable) {
        ensureMember(conversationId, userId);
        return messageRepository
                .findByConversationIdAndIsDeletedFalseOrderBySentAtDesc(conversationId, pageable)
                .map(this::toMessageResponse);
    }

    @Transactional
    public MessageResponse sendMessage(UUID conversationId, SendMessageRequest request, UUID senderId) {
        ensureMember(conversationId, senderId);
        MessageType messageType = parseMessageType(request.messageType());
        validateMessageBody(request.content(), request.mediaUrl(), messageType);

        Message message = Message.builder()
                .conversationId(conversationId)
                .senderId(senderId)
                .content(request.content())
                .mediaUrl(request.mediaUrl())
                .messageType(messageType)
                .sentAt(Instant.now())
                .build();

        Message saved = messageRepository.save(message);
        markMessageRead(saved.getId(), senderId);
        conversationRepository.findByIdAndIsDeletedFalse(conversationId)
                .ifPresent(conversationRepository::save);

        MessageResponse response = toMessageResponse(saved);
        publishMessage(response, senderId);
        notifyMembers(response, senderId);
        return response;
    }

    @Transactional
    public MessageResponse sendMessage(SendMessageWSRequest request, UUID senderId) {
        SendMessageRequest restRequest = new SendMessageRequest(
                request.content(),
                request.mediaUrl(),
                request.messageType());
        return sendMessage(request.conversationId(), restRequest, senderId);
    }

    @Transactional
    public ConversationResponse addMembers(UUID conversationId, List<UUID> memberIds, UUID requesterId) {
        Conversation conversation = conversationRepository.findByIdAndIsDeletedFalse(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay cuoc tro chuyen: " + conversationId));
        ensureGroupAdmin(conversation, requesterId);

        List<ConversationMember> newMembers = memberIds.stream()
                .distinct()
                .filter(memberId -> !conversationMemberRepository.existsByConversationIdAndUserId(conversationId, memberId))
                .map(memberId -> {
                    findUser(memberId);
                    return ConversationMember.builder()
                            .conversationId(conversationId)
                            .userId(memberId)
                            .joinAt(Instant.now())
                            .isAdmin(false)
                            .build();
                })
                .toList();
        conversationMemberRepository.saveAll(newMembers);
        return toConversationResponse(conversation, requesterId);
    }

    @Transactional
    public ConversationResponse updateConversation(
            UUID conversationId,
            UpdateConversationRequest request,
            UUID requesterId) {
        Conversation conversation = conversationRepository.findByIdAndIsDeletedFalse(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay cuoc tro chuyen: " + conversationId));
        ensureGroupAdmin(conversation, requesterId);

        if (request.name() != null) {
            if (!StringUtils.hasText(request.name())) {
                throw new BusinessException("Ten nhom khong duoc de trong");
            }
            conversation.setName(request.name());
        }
        if (request.avatarUrl() != null) {
            conversation.setAvatarUrl(StringUtils.hasText(request.avatarUrl()) ? request.avatarUrl() : null);
        }

        return toConversationResponse(conversationRepository.save(conversation), requesterId);
    }

    @Transactional
    public ConversationResponse removeMember(UUID conversationId, UUID memberId, UUID requesterId) {
        Conversation conversation = conversationRepository.findByIdAndIsDeletedFalse(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay cuoc tro chuyen: " + conversationId));
        ensureGroupAdmin(conversation, requesterId);
        if (requesterId.equals(memberId)) {
            throw new BusinessException("Admin nhom dung endpoint roi nhom de tu roi khoi nhom");
        }
        ensureMember(conversationId, memberId);

        conversationMemberRepository.deleteByConversationIdAndUserId(conversationId, memberId);
        return toConversationResponse(conversation, requesterId);
    }

    @Transactional
    public void leaveConversation(UUID conversationId, UUID userId) {
        Conversation conversation = conversationRepository.findByIdAndIsDeletedFalse(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay cuoc tro chuyen: " + conversationId));
        ConversationMember member = ensureMember(conversationId, userId);
        if (conversation.getType() != ConversationType.GROUP) {
            throw new BusinessException("Khong the roi khoi cuoc tro chuyen DIRECT");
        }

        List<ConversationMember> members = conversationMemberRepository.findByConversationId(conversationId);
        if (members.size() <= 1) {
            throw new BusinessException("Khong the roi nhom khi chi con mot thanh vien");
        }
        boolean hasOtherAdmin = members.stream()
                .anyMatch(other -> !other.getUserId().equals(userId) && Boolean.TRUE.equals(other.getIsAdmin()));
        if (Boolean.TRUE.equals(member.getIsAdmin()) && !hasOtherAdmin) {
            throw new BusinessException("Can chuyen quyen admin cho thanh vien khac truoc khi roi nhom");
        }

        conversationMemberRepository.deleteByConversationIdAndUserId(conversationId, userId);
    }

    @Transactional
    public void markAsRead(UUID conversationId, UUID userId) {
        ConversationMember member = ensureMember(conversationId, userId);
        Instant readAt = Instant.now();
        conversationMemberRepository.updateLastReadAt(conversationId, userId, readAt);

        List<UUID> unreadMessageIds = member.getLastReadAt() == null
                ? messageRepository.findUnreadMessageIds(conversationId, userId)
                : messageRepository.findUnreadMessageIdsAfter(conversationId, userId, member.getLastReadAt());
        if (unreadMessageIds.isEmpty()) {
            return;
        }

        List<UUID> readMessageIds = messageReadRepository.findReadMessageIds(userId, unreadMessageIds);
        Set<UUID> alreadyRead = new HashSet<>(readMessageIds);

        List<MessageRead> newReads = unreadMessageIds.stream()
                .filter(messageId -> !alreadyRead.contains(messageId))
                .map(messageId -> MessageRead.builder()
                        .messageId(messageId)
                        .userId(userId)
                        .readAt(readAt)
                        .build())
                .toList();
        messageReadRepository.saveAll(newReads);
    }

    private void publishMessage(MessageResponse response, UUID senderId) {
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

    private void notifyMembers(MessageResponse response, UUID senderId) {
        conversationMemberRepository.findByConversationId(response.conversationId())
                .stream()
                .map(ConversationMember::getUserId)
                .filter(userId -> !userId.equals(senderId))
                .forEach(userId -> notificationService.sendToUser(
                        userId,
                        NotificationType.NEW_MESSAGE,
                        "Tin nhan moi",
                        response.contentPreview(),
                        "CONVERSATION",
                        response.conversationId().toString(),
                        true));
    }

    private ConversationResponse toConversationResponse(Conversation conversation, UUID viewerId) {
        List<ConversationMember> members = conversationMemberRepository.findByConversationId(conversation.getId());
        Map<UUID, UserEntity> usersById = userRepository.findAllById(
                        members.stream().map(ConversationMember::getUserId).toList())
                .stream()
                .collect(Collectors.toMap(UserEntity::getId, Function.identity()));

        ConversationMember viewerMember = members.stream()
                .filter(member -> member.getUserId().equals(viewerId))
                .findFirst()
                .orElse(null);
        Message lastMessage = messageRepository
                .findFirstByConversationIdAndIsDeletedFalseOrderBySentAtDesc(conversation.getId())
                .orElse(null);

        return new ConversationResponse(
                conversation.getId(),
                conversation.getType().name(),
                resolveConversationName(conversation, viewerId, members, usersById),
                conversation.getAvatarUrl(),
                members.stream()
                        .map(member -> toMemberInfo(member, usersById.get(member.getUserId())))
                        .toList(),
                lastMessage != null ? toMessageInfo(lastMessage) : null,
                viewerMember == null ? 0 : (viewerMember.getLastReadAt() == null
                        ? messageRepository.countUnread(conversation.getId(), viewerId)
                        : messageRepository.countUnreadAfter(conversation.getId(), viewerId, viewerMember.getLastReadAt())),
                conversation.getCreatedAt()
        );
    }

    private MessageResponse toMessageResponse(Message message) {
        UserEntity sender = findUser(message.getSenderId());
        List<UUID> readByUserIds = messageReadRepository.findByMessageId(message.getId())
                .stream()
                .map(MessageRead::getUserId)
                .toList();

        return new MessageResponse(
                message.getId(),
                message.getConversationId(),
                new MessageResponse.SenderInfo(sender.getId(), sender.getFullName(), sender.getAvatarUrl()),
                message.getContent(),
                message.getMediaUrl(),
                message.getMessageType().name(),
                message.getSentAt(),
                readByUserIds
        );
    }

    private ConversationResponse.MemberInfo toMemberInfo(ConversationMember member, UserEntity user) {
        return new ConversationResponse.MemberInfo(
                member.getUserId(),
                user != null ? user.getFullName() : "Khong xac dinh",
                user != null ? user.getEmployeeCode() : null,
                user != null ? user.getAvatarUrl() : null,
                member.getIsAdmin()
        );
    }

    private ConversationResponse.MessageInfo toMessageInfo(Message message) {
        UserEntity sender = userRepository.findByIdAndIsDeletedFalse(message.getSenderId()).orElse(null);
        return new ConversationResponse.MessageInfo(
                message.getId(),
                sender != null ? sender.getFullName() : "Khong xac dinh",
                message.getContent(),
                message.getMessageType().name(),
                message.getSentAt()
        );
    }

    private String resolveConversationName(
            Conversation conversation,
            UUID viewerId,
            List<ConversationMember> members,
            Map<UUID, UserEntity> usersById) {
        if (conversation.getType() == ConversationType.GROUP) {
            return conversation.getName();
        }
        return members.stream()
                .map(ConversationMember::getUserId)
                .filter(userId -> !userId.equals(viewerId))
                .map(usersById::get)
                .filter(Objects::nonNull)
                .map(UserEntity::getFullName)
                .findFirst()
                .orElse("Direct chat");
    }

    private ConversationMember ensureMember(UUID conversationId, UUID userId) {
        conversationRepository.findByIdAndIsDeletedFalse(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay cuoc tro chuyen: " + conversationId));
        return conversationMemberRepository.findByConversationIdAndUserId(conversationId, userId)
                .orElseThrow(() -> new BusinessException("Ban khong phai thanh vien cua cuoc tro chuyen nay", 403));
    }

    private ConversationMember ensureGroupAdmin(Conversation conversation, UUID requesterId) {
        ConversationMember requester = ensureMember(conversation.getId(), requesterId);
        if (conversation.getType() != ConversationType.GROUP) {
            throw new BusinessException("Thao tac nay chi ap dung cho cuoc tro chuyen nhom");
        }
        if (!Boolean.TRUE.equals(requester.getIsAdmin())) {
            throw new BusinessException("Chi admin nhom moi co quyen thuc hien thao tac nay", 403);
        }
        return requester;
    }

    private UserEntity findUser(UUID userId) {
        return userRepository.findByIdAndIsDeletedFalse(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay nguoi dung: " + userId));
    }

    private void markMessageRead(UUID messageId, UUID userId) {
        if (!messageReadRepository.existsByMessageIdAndUserId(messageId, userId)) {
            messageReadRepository.save(MessageRead.builder()
                    .messageId(messageId)
                    .userId(userId)
                    .readAt(Instant.now())
                    .build());
        }
    }

    private ConversationType parseConversationType(String value) {
        try {
            return ConversationType.valueOf(value);
        } catch (Exception ex) {
            throw new BusinessException("Loai cuoc tro chuyen khong hop le: " + value);
        }
    }

    private MessageType parseMessageType(String value) {
        try {
            return MessageType.valueOf(value);
        } catch (Exception ex) {
            throw new BusinessException("Loai tin nhan khong hop le: " + value);
        }
    }

    private List<UUID> normalizeMemberIds(List<UUID> memberIds, UUID creatorId) {
        List<UUID> normalized = new ArrayList<>(memberIds != null ? memberIds : List.of());
        normalized.add(creatorId);
        return normalized.stream().distinct().toList();
    }

    private void validateConversationRequest(
            ConversationType type,
            String name,
            List<UUID> memberIds,
            UUID creatorId) {
        if (type == ConversationType.DIRECT && memberIds.size() != 2) {
            throw new BusinessException("Cuoc tro chuyen DIRECT can dung 2 thanh vien");
        }
        if (type == ConversationType.GROUP && memberIds.size() < 3) {
            throw new BusinessException("Cuoc tro chuyen GROUP can it nhat 3 thanh vien gom nguoi tao");
        }
        if (type == ConversationType.GROUP && !StringUtils.hasText(name)) {
            throw new BusinessException("Ten nhom khong duoc de trong");
        }
        if (!memberIds.contains(creatorId)) {
            throw new BusinessException("Nguoi tao phai la thanh vien cua cuoc tro chuyen");
        }
    }

    private void validateMessageBody(String content, String mediaUrl, MessageType messageType) {
        if (messageType == MessageType.TEXT && !StringUtils.hasText(content)) {
            throw new BusinessException("Tin nhan TEXT phai co noi dung");
        }
        if ((messageType == MessageType.IMAGE || messageType == MessageType.FILE)
                && !StringUtils.hasText(mediaUrl)) {
            throw new BusinessException("Tin nhan media phai co mediaUrl");
        }
    }
}
