package com.suachuabientan.system_internal.modules.messaging.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.messaging.dto.request.CreateConversationRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.request.UpdateMemberRoleRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.request.SendMessageRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.request.SendMessageWSRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.request.UpdateMessageRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.request.UpdateConversationRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.response.ConversationResponse;
import com.suachuabientan.system_internal.modules.messaging.dto.response.MessageResponse;
import com.suachuabientan.system_internal.modules.messaging.entity.Conversation;
import com.suachuabientan.system_internal.modules.messaging.entity.ConversationMember;
import com.suachuabientan.system_internal.modules.messaging.entity.Message;
import com.suachuabientan.system_internal.modules.messaging.entity.MessageDeletion;
import com.suachuabientan.system_internal.modules.messaging.entity.MessageMention;
import com.suachuabientan.system_internal.modules.messaging.entity.MessageReaction;
import com.suachuabientan.system_internal.modules.messaging.entity.MessageRead;
import com.suachuabientan.system_internal.modules.messaging.enums.ConversationMemberRole;
import com.suachuabientan.system_internal.modules.messaging.enums.ConversationType;
import com.suachuabientan.system_internal.modules.messaging.enums.MessageType;
import com.suachuabientan.system_internal.modules.messaging.repository.ConversationMemberRepository;
import com.suachuabientan.system_internal.modules.messaging.repository.ConversationRepository;
import com.suachuabientan.system_internal.modules.messaging.repository.MessageDeletionRepository;
import com.suachuabientan.system_internal.modules.messaging.repository.MessageMentionRepository;
import com.suachuabientan.system_internal.modules.messaging.repository.MessageReadRepository;
import com.suachuabientan.system_internal.modules.messaging.repository.MessageReactionRepository;
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
import org.springframework.web.multipart.MultipartFile;

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
    private final MessageDeletionRepository messageDeletionRepository;
    private final MessageReactionRepository messageReactionRepository;
    private final MessageMentionRepository messageMentionRepository;
    private final UserRepository userRepository;
    private final SimpMessagingTemplate messagingTemplate;
    private final NotificationService notificationService;
    private final MessageMediaStorageService messageMediaStorageService;

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
                    .orElseThrow(() -> new BusinessException("Cuộc trò chuyện DIRECT cần có một thành viên khác"));
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
                        .role(memberId.equals(creatorId)
                                ? ConversationMemberRole.ADMIN
                                : ConversationMemberRole.MEMBER)
                        .canChat(true)
                        .notificationsMuted(false)
                        .build())
                .toList();
        conversationMemberRepository.saveAll(members);

        return toConversationResponse(saved, creatorId);
    }

    @Transactional(readOnly = true)
    public Page<MessageResponse> getMessages(UUID conversationId, UUID userId, Pageable pageable) {
        ensureMember(conversationId, userId);
        return messageRepository
                .findVisibleByConversation(conversationId, userId, pageable)
                .map(this::toMessageResponse);
    }

    @Transactional(readOnly = true)
    public Page<MessageResponse> searchMessages(UUID conversationId, UUID userId, String query, Pageable pageable) {
        ensureMember(conversationId, userId);
        if (!StringUtils.hasText(query)) {
            throw new BusinessException("Tu khoa tim kiem khong duoc de trong", 400);
        }
        return messageRepository
                .searchVisibleByConversation(conversationId, userId, query.trim(), pageable)
                .map(this::toMessageResponse);
    }

    @Transactional(readOnly = true)
    public Page<MessageResponse> getGallery(UUID conversationId, UUID userId, String type, Pageable pageable) {
        ensureMember(conversationId, userId);
        String normalized = type == null ? "MEDIA" : type.trim().toUpperCase(Locale.ROOT);
        if ("LINKS".equals(normalized)) {
            return messageRepository.findVisibleLinks(conversationId, userId, pageable)
                    .map(this::toMessageResponse);
        }

        List<MessageType> messageTypes = switch (normalized) {
            case "FILES", "DOCS" -> List.of(MessageType.FILE);
            case "ALL" -> List.of(
                    MessageType.IMAGE,
                    MessageType.VIDEO,
                    MessageType.GIF,
                    MessageType.STICKER,
                    MessageType.FILE);
            case "MEDIA" -> List.of(
                    MessageType.IMAGE,
                    MessageType.VIDEO,
                    MessageType.GIF,
                    MessageType.STICKER);
            default -> throw new BusinessException("Loai thu vien khong hop le: " + type, 400);
        };
        return messageRepository.findVisibleByMessageTypes(conversationId, userId, messageTypes, pageable)
                .map(this::toMessageResponse);
    }

    @Transactional
    public MessageResponse sendMessage(UUID conversationId, SendMessageRequest request, UUID senderId) {
        ConversationMember sender = ensureMember(conversationId, senderId);
        ensureCanChat(sender);
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
        saveMentions(saved.getId(), conversationId, request.mentionUserIds());
        markMessageRead(saved.getId(), senderId);
        conversationRepository.findByIdAndIsDeletedFalse(conversationId)
                .ifPresent(conversationRepository::save);

        MessageResponse response = toMessageResponse(saved);
        publishMessage(response, senderId);
        notifyMembers(response, senderId);
        return response;
    }

    @Transactional
    public MessageResponse sendMediaMessage(
            UUID conversationId,
            MultipartFile file,
            String content,
            String type,
            UUID senderId) {
        ensureMember(conversationId, senderId);
        MessageType messageType = parseMessageType(type);
        if (messageType != MessageType.IMAGE
                && messageType != MessageType.VIDEO
                && messageType != MessageType.FILE) {
            throw new BusinessException("Loại tin nhắn upload không hợp lệ: " + type);
        }

        MessageMediaStorageService.StoredMedia stored = messageMediaStorageService.store(file, messageType);
        String effectiveContent = StringUtils.hasText(content)
                ? content.trim()
                : (messageType == MessageType.FILE ? stored.originalFileName() : null);
        return sendMessage(
                conversationId,
                new SendMessageRequest(effectiveContent, stored.publicUrl(), messageType.name(), null),
                senderId);
    }

    @Transactional
    public MessageResponse sendMessage(SendMessageWSRequest request, UUID senderId) {
        SendMessageRequest restRequest = new SendMessageRequest(
                request.content(),
                request.mediaUrl(),
                request.messageType(),
                null);
        return sendMessage(request.conversationId(), restRequest, senderId);
    }

    @Transactional
    public MessageResponse updateMessage(
            UUID conversationId,
            UUID messageId,
            UpdateMessageRequest request,
            UUID requesterId) {
        ensureMember(conversationId, requesterId);
        Message message = findMessage(conversationId, messageId);
        if (!message.getSenderId().equals(requesterId)) {
            throw new BusinessException("Chi nguoi gui moi duoc sua tin nhan", 403);
        }
        if (message.getDeletedForEveryoneAt() != null) {
            throw new BusinessException("Tin nhan da bi thu hoi nen khong the sua", 400);
        }
        if (message.getMessageType() != MessageType.TEXT) {
            throw new BusinessException("Chi ho tro sua tin nhan van ban", 400);
        }
        if (!StringUtils.hasText(request.content())) {
            throw new BusinessException("Noi dung tin nhan khong duoc de trong", 400);
        }

        message.setContent(request.content().trim());
        message.setEditedAt(Instant.now());
        Message saved = messageRepository.save(message);
        saveMentions(saved.getId(), conversationId, request.mentionUserIds());
        MessageResponse response = toMessageResponse(saved);
        publishConversationEvent(conversationId, "MESSAGE_UPDATED", response);
        return response;
    }

    @Transactional
    public MessageResponse deleteMessage(
            UUID conversationId,
            UUID messageId,
            String scope,
            UUID requesterId) {
        ConversationMember requester = ensureMember(conversationId, requesterId);
        Message message = findMessage(conversationId, messageId);
        String normalizedScope = scope == null ? "ME" : scope.trim().toUpperCase(Locale.ROOT);
        if ("ME".equals(normalizedScope)) {
            if (!messageDeletionRepository.existsByMessageIdAndUserId(messageId, requesterId)) {
                messageDeletionRepository.save(MessageDeletion.builder()
                        .messageId(messageId)
                        .userId(requesterId)
                        .deletedAt(Instant.now())
                        .build());
            }
            return toMessageResponse(message);
        }
        if (!"EVERYONE".equals(normalizedScope)) {
            throw new BusinessException("Pham vi xoa tin nhan khong hop le", 400);
        }
        if (!message.getSenderId().equals(requesterId) && !canModerate(requester)) {
            throw new BusinessException("Chi nguoi gui hoac quan tri vien moi duoc thu hoi tin nhan", 403);
        }

        message.setDeletedForEveryoneAt(Instant.now());
        message.setDeletedByUserId(requesterId);
        Message saved = messageRepository.save(message);
        MessageResponse response = toMessageResponse(saved);
        publishConversationEvent(conversationId, "MESSAGE_DELETED", response);
        return response;
    }

    @Transactional
    public MessageResponse addReaction(UUID conversationId, UUID messageId, String emoji, UUID userId) {
        ensureMember(conversationId, userId);
        Message message = findMessage(conversationId, messageId);
        String normalizedEmoji = normalizeEmoji(emoji);
        if (!messageReactionRepository.existsById(new com.suachuabientan.system_internal.modules.messaging.entity.MessageReactionId(
                messageId,
                userId,
                normalizedEmoji))) {
            messageReactionRepository.save(MessageReaction.builder()
                    .messageId(messageId)
                    .userId(userId)
                    .emoji(normalizedEmoji)
                    .reactedAt(Instant.now())
                    .build());
        }
        MessageResponse response = toMessageResponse(message);
        publishConversationEvent(conversationId, "MESSAGE_REACTION_UPDATED", response);
        return response;
    }

    @Transactional
    public MessageResponse removeReaction(UUID conversationId, UUID messageId, String emoji, UUID userId) {
        ensureMember(conversationId, userId);
        Message message = findMessage(conversationId, messageId);
        messageReactionRepository.deleteByMessageIdAndUserIdAndEmoji(messageId, userId, normalizeEmoji(emoji));
        MessageResponse response = toMessageResponse(message);
        publishConversationEvent(conversationId, "MESSAGE_REACTION_UPDATED", response);
        return response;
    }

    @Transactional
    public ConversationResponse updateMemberRole(
            UUID conversationId,
            UUID memberId,
            UpdateMemberRoleRequest request,
            UUID requesterId) {
        Conversation conversation = conversationRepository.findByIdAndIsDeletedFalse(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay cuoc tro chuyen: " + conversationId));
        ConversationMember requester = ensureGroupAdmin(conversation, requesterId);
        ConversationMember target = ensureMember(conversationId, memberId);
        if (requester.getUserId().equals(memberId) && request.role() != null && !"ADMIN".equalsIgnoreCase(request.role())) {
            throw new BusinessException("Khong the tu ha quyen admin cua chinh minh", 400);
        }

        ConversationMemberRole role = parseMemberRole(request.role());
        target.setRole(role);
        target.setIsAdmin(role == ConversationMemberRole.ADMIN);
        if (request.canChat() != null) {
            target.setCanChat(request.canChat());
            target.setBannedAt(Boolean.FALSE.equals(request.canChat()) ? Instant.now() : null);
        }
        conversationMemberRepository.save(target);
        return toConversationResponse(conversation, requester.getUserId());
    }

    @Transactional
    public ConversationResponse setConversationPinned(UUID conversationId, UUID userId, boolean pinned) {
        Conversation conversation = conversationRepository.findByIdAndIsDeletedFalse(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay cuoc tro chuyen: " + conversationId));
        ConversationMember member = ensureMember(conversationId, userId);
        member.setPinnedAt(pinned ? Instant.now() : null);
        conversationMemberRepository.save(member);
        return toConversationResponse(conversation, userId);
    }

    @Transactional
    public ConversationResponse setNotificationsMuted(UUID conversationId, UUID userId, boolean muted) {
        Conversation conversation = conversationRepository.findByIdAndIsDeletedFalse(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay cuoc tro chuyen: " + conversationId));
        ConversationMember member = ensureMember(conversationId, userId);
        member.setNotificationsMuted(muted);
        conversationMemberRepository.save(member);
        return toConversationResponse(conversation, userId);
    }

    @Transactional
    public ConversationResponse pinMessage(UUID conversationId, UUID messageId, UUID requesterId) {
        Conversation conversation = conversationRepository.findByIdAndIsDeletedFalse(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay cuoc tro chuyen: " + conversationId));
        ConversationMember requester = ensureMember(conversationId, requesterId);
        if (conversation.getType() == ConversationType.GROUP && !canModerate(requester)) {
            throw new BusinessException("Chi admin hoac moderator moi duoc ghim tin nhan nhom", 403);
        }
        Message message = findMessage(conversationId, messageId);
        if (message.getDeletedForEveryoneAt() != null) {
            throw new BusinessException("Khong the ghim tin nhan da thu hoi", 400);
        }

        conversation.setPinnedMessageId(messageId);
        conversation.setPinnedMessageAt(Instant.now());
        conversation.setPinnedMessageBy(requesterId);
        Conversation saved = conversationRepository.save(conversation);
        ConversationResponse response = toConversationResponse(saved, requesterId);
        publishConversationEvent(conversationId, "PINNED_MESSAGE_UPDATED", response);
        return response;
    }

    @Transactional
    public ConversationResponse unpinMessage(UUID conversationId, UUID requesterId) {
        Conversation conversation = conversationRepository.findByIdAndIsDeletedFalse(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay cuoc tro chuyen: " + conversationId));
        ConversationMember requester = ensureMember(conversationId, requesterId);
        if (conversation.getType() == ConversationType.GROUP && !canModerate(requester)) {
            throw new BusinessException("Chi admin hoac moderator moi duoc bo ghim tin nhan nhom", 403);
        }

        conversation.setPinnedMessageId(null);
        conversation.setPinnedMessageAt(null);
        conversation.setPinnedMessageBy(null);
        Conversation saved = conversationRepository.save(conversation);
        ConversationResponse response = toConversationResponse(saved, requesterId);
        publishConversationEvent(conversationId, "PINNED_MESSAGE_UPDATED", response);
        return response;
    }

    public void publishTyping(UUID conversationId, UUID userId, boolean typing) {
        ensureMember(conversationId, userId);
        Map<String, Object> event = Map.of(
                "type", "TYPING",
                "conversationId", conversationId,
                "userId", userId,
                "typing", typing,
                "timestamp", Instant.now().toString());
        publishConversationEvent(conversationId, "TYPING", event);
    }

    @Transactional
    public ConversationResponse addMembers(UUID conversationId, List<UUID> memberIds, UUID requesterId) {
        Conversation conversation = conversationRepository.findByIdAndIsDeletedFalse(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện: " + conversationId));
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
                            .role(ConversationMemberRole.MEMBER)
                            .canChat(true)
                            .notificationsMuted(false)
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
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện: " + conversationId));
        ensureGroupAdmin(conversation, requesterId);

        if (request.name() != null) {
            if (!StringUtils.hasText(request.name())) {
                throw new BusinessException("Tên nhóm không được để trống");
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
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện: " + conversationId));
        ensureGroupAdmin(conversation, requesterId);
        if (requesterId.equals(memberId)) {
            throw new BusinessException("Admin nhóm dùng endpoint này để rời nhóm");
        }
        ensureMember(conversationId, memberId);

        conversationMemberRepository.deleteByConversationIdAndUserId(conversationId, memberId);
        return toConversationResponse(conversation, requesterId);
    }

    @Transactional
    public void leaveConversation(UUID conversationId, UUID userId) {
        Conversation conversation = conversationRepository.findByIdAndIsDeletedFalse(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện: " + conversationId));
        ConversationMember member = ensureMember(conversationId, userId);
        if (conversation.getType() != ConversationType.GROUP) {
            throw new BusinessException("Không thể rời khỏi cuộc trò chuyện DIRECT");
        }

        List<ConversationMember> members = conversationMemberRepository.findByConversationId(conversationId);
        if (members.size() <= 1) {
            throw new BusinessException("Không thể rời nhóm khi chỉ còn một thành viên");
        }
        boolean hasOtherAdmin = members.stream()
                .anyMatch(other -> !other.getUserId().equals(userId) && Boolean.TRUE.equals(other.getIsAdmin()));
        if (Boolean.TRUE.equals(member.getIsAdmin()) && !hasOtherAdmin) {
            throw new BusinessException("Cần chuyển quyền admin cho thành viên khác trước khi rời nhóm");
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

    private void saveMentions(UUID messageId, UUID conversationId, List<UUID> mentionUserIds) {
        messageMentionRepository.deleteByMessageId(messageId);
        if (mentionUserIds == null || mentionUserIds.isEmpty()) {
            return;
        }
        List<MessageMention> mentions = mentionUserIds.stream()
                .filter(Objects::nonNull)
                .distinct()
                .peek(mentionedUserId -> ensureMember(conversationId, mentionedUserId))
                .map(mentionedUserId -> MessageMention.builder()
                        .messageId(messageId)
                        .mentionedUserId(mentionedUserId)
                        .build())
                .toList();
        messageMentionRepository.saveAll(mentions);
    }

    private Message findMessage(UUID conversationId, UUID messageId) {
        Message message = messageRepository.findById(messageId)
                .filter(candidate -> Boolean.FALSE.equals(candidate.getIsDeleted()))
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay tin nhan: " + messageId));
        if (!message.getConversationId().equals(conversationId)) {
            throw new BusinessException("Tin nhan khong thuoc cuoc tro chuyen nay", 400);
        }
        return message;
    }

    private void ensureCanChat(ConversationMember member) {
        if (Boolean.FALSE.equals(member.getCanChat()) || member.getBannedAt() != null) {
            throw new BusinessException("Ban dang bi cam chat trong cuoc tro chuyen nay", 403);
        }
        if (member.getMutedUntil() != null && member.getMutedUntil().isAfter(Instant.now())) {
            throw new BusinessException("Ban dang bi tam khoa chat den " + member.getMutedUntil(), 403);
        }
    }

    private boolean canModerate(ConversationMember member) {
        ConversationMemberRole role = member.getRole();
        return role == ConversationMemberRole.ADMIN || role == ConversationMemberRole.MODERATOR;
    }

    private String normalizeEmoji(String emoji) {
        String normalized = emoji == null ? "" : emoji.trim();
        Set<String> allowed = Set.of("👍", "❤️", "😂", "😮", "😢", "😡");
        if (!allowed.contains(normalized)) {
            throw new BusinessException("Emoji reaction khong duoc ho tro", 400);
        }
        return normalized;
    }

    private ConversationMemberRole parseMemberRole(String value) {
        try {
            return ConversationMemberRole.valueOf(value.trim().toUpperCase(Locale.ROOT));
        } catch (Exception error) {
            throw new BusinessException("Vai tro thanh vien khong hop le: " + value, 400);
        }
    }

    private void publishConversationEvent(UUID conversationId, String type, Object payload) {
        messagingTemplate.convertAndSend(
                "/topic/conversation/" + conversationId + "/events",
                Map.of(
                        "type", type,
                        "conversationId", conversationId,
                        "payload", payload,
                        "timestamp", Instant.now().toString()));
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
                .filter(member -> !member.getUserId().equals(senderId))
                .filter(member -> !Boolean.TRUE.equals(member.getNotificationsMuted()))
                .forEach(member -> notificationService.sendToUser(
                        member.getUserId(),
                        NotificationType.NEW_MESSAGE,
                        "Tin nhắn mới",
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
        Message pinnedMessage = conversation.getPinnedMessageId() == null
                ? null
                : messageRepository.findById(conversation.getPinnedMessageId())
                .filter(message -> Boolean.FALSE.equals(message.getIsDeleted()))
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
                pinnedMessage != null ? toMessageInfo(pinnedMessage) : null,
                viewerMember != null && viewerMember.getPinnedAt() != null,
                viewerMember == null ? null : viewerMember.getPinnedAt(),
                viewerMember != null && Boolean.TRUE.equals(viewerMember.getNotificationsMuted()),
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
        List<UUID> mentionUserIds = messageMentionRepository.findByMessageId(message.getId())
                .stream()
                .map(MessageMention::getMentionedUserId)
                .toList();
        List<MessageResponse.ReactionInfo> reactions = reactionInfo(message.getId());
        boolean deletedForEveryone = message.getDeletedForEveryoneAt() != null;

        return new MessageResponse(
                message.getId(),
                message.getConversationId(),
                new MessageResponse.SenderInfo(sender.getId(), sender.getFullName(), sender.getAvatarUrl()),
                deletedForEveryone ? "Tin nhan da duoc thu hoi" : message.getContent(),
                deletedForEveryone ? null : message.getMediaUrl(),
                deletedForEveryone ? MessageType.SYSTEM.name() : message.getMessageType().name(),
                message.getSentAt(),
                message.getEditedAt(),
                message.getDeletedForEveryoneAt(),
                readByUserIds,
                mentionUserIds,
                reactions
        );
    }

    private List<MessageResponse.ReactionInfo> reactionInfo(UUID messageId) {
        return messageReactionRepository.findByMessageId(messageId)
                .stream()
                .collect(Collectors.groupingBy(MessageReaction::getEmoji))
                .entrySet()
                .stream()
                .map(entry -> new MessageResponse.ReactionInfo(
                        entry.getKey(),
                        entry.getValue().size(),
                        entry.getValue().stream().map(MessageReaction::getUserId).toList()))
                .sorted(Comparator.comparing(MessageResponse.ReactionInfo::emoji))
                .toList();
    }

    private ConversationResponse.MemberInfo toMemberInfo(ConversationMember member, UserEntity user) {
        return new ConversationResponse.MemberInfo(
                member.getUserId(),
                user != null ? user.getFullName() : "Không xác định",
                user != null ? user.getEmployeeCode() : null,
                user != null ? user.getAvatarUrl() : null,
                member.getIsAdmin(),
                member.getRole() == null ? ConversationMemberRole.MEMBER.name() : member.getRole().name(),
                member.getCanChat()
        );
    }

    private ConversationResponse.MessageInfo toMessageInfo(Message message) {
        UserEntity sender = userRepository.findByIdAndIsDeletedFalse(message.getSenderId()).orElse(null);
        return new ConversationResponse.MessageInfo(
                message.getId(),
                sender != null ? sender.getFullName() : "Không xác định",
                message.getDeletedForEveryoneAt() != null ? "Tin nhan da duoc thu hoi" : message.getContent(),
                message.getDeletedForEveryoneAt() != null ? MessageType.SYSTEM.name() : message.getMessageType().name(),
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
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện: " + conversationId));
        return conversationMemberRepository.findByConversationIdAndUserId(conversationId, userId)
                .orElseThrow(() -> new BusinessException("Bạn không phải là thành viên của cuộc trò chuyện này", 403));
    }

    private ConversationMember ensureGroupAdmin(Conversation conversation, UUID requesterId) {
        ConversationMember requester = ensureMember(conversation.getId(), requesterId);
        if (conversation.getType() != ConversationType.GROUP) {
            throw new BusinessException("Thao tác này chỉ áp dụng cho cuộc trò chuyện nhóm");
        }
        if (!Boolean.TRUE.equals(requester.getIsAdmin())) {
            throw new BusinessException("Chỉ admin nhóm mới có quyền thực hiện thao tác này", 403);
        }
        return requester;
    }

    private UserEntity findUser(UUID userId) {
        return userRepository.findByIdAndIsDeletedFalse(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng: " + userId));
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
            throw new BusinessException("Loại cuộc trò chuyện không hợp lệ: " + value);
        }
    }

    private MessageType parseMessageType(String value) {
        try {
            return MessageType.valueOf(value);
        } catch (Exception ex) {
            throw new BusinessException("Loại tin nhắn không hợp lệ: " + value);
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
            throw new BusinessException("Cuộc trò chuyện DIRECT cần có 2 thành viên");
        }
        if (type == ConversationType.GROUP && memberIds.size() < 3) {
            throw new BusinessException("Cuộc trò chuyện GROUP cần ít nhất 3 thành viên gồm người tạo");
        }
        if (type == ConversationType.GROUP && !StringUtils.hasText(name)) {
            throw new BusinessException("Tên nhóm không được để trống");
        }
        if (!memberIds.contains(creatorId)) {
            throw new BusinessException("Người tạo phải là thành viên của cuộc trò chuyện");
        }
    }

    private void validateMessageBody(String content, String mediaUrl, MessageType messageType) {
        if (messageType == MessageType.TEXT && !StringUtils.hasText(content)) {
            throw new BusinessException("Tin nhắn TEXT phải có nội dung");
        }
        if ((messageType == MessageType.IMAGE
                || messageType == MessageType.VIDEO
                || messageType == MessageType.FILE
                || messageType == MessageType.STICKER
                || messageType == MessageType.GIF)
                && !StringUtils.hasText(mediaUrl)) {
            throw new BusinessException("Tin nhắn media phải có mediaUrl");
        }
    }
}
