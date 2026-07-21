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
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.time.Instant;
import java.util.*;

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
    private final MessageMediaStorageService messageMediaStorageService;
    private final MessagingRequestValidator requestValidator;
    private final MessagingPermissionPolicy permissionPolicy;
    private final MessagingRealtimePublisher realtimePublisher;
    private final MessagingResponseMapper responseMapper;

    @Transactional(readOnly = true)
    public List<ConversationResponse> getMyConversations(UUID userId) {
        return conversationRepository.findByMember(userId)
                .stream()
                .map(conversation -> responseMapper.toConversationResponse(conversation, userId))
                .toList();
    }

    @Transactional
    public ConversationResponse createConversation(CreateConversationRequest request, UUID creatorId) {
        ConversationType type = requestValidator.parseConversationType(request.type());
        List<UUID> memberIds = requestValidator.normalizeMemberIds(request.memberIds(), creatorId);
        requestValidator.validateConversationRequest(type, request.name(), memberIds, creatorId);

        if (type == ConversationType.DIRECT) {
            UUID otherUserId = memberIds.stream()
                    .filter(memberId -> !memberId.equals(creatorId))
                    .findFirst()
                    .orElseThrow(() -> new BusinessException("Cuộc trò chuyện DIRECT cần có một thành viên khác"));
            Optional<Conversation> existing = conversationRepository.findDirectConversation(creatorId, otherUserId);
            if (existing.isPresent()) {
                return responseMapper.toConversationResponse(existing.get(), creatorId);
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

        return responseMapper.toConversationResponse(saved, creatorId);
    }

    @Transactional(readOnly = true)
    public Page<MessageResponse> getMessages(UUID conversationId, UUID userId, Pageable pageable) {
        ensureMember(conversationId, userId);
        return messageRepository
                .findVisibleByConversation(conversationId, userId, pageable)
                .map(responseMapper::toMessageResponse);
    }

    @Transactional(readOnly = true)
    public Page<MessageResponse> searchMessages(UUID conversationId, UUID userId, String query, Pageable pageable) {
        ensureMember(conversationId, userId);
        if (!StringUtils.hasText(query)) {
            throw new BusinessException("Tu khoa tim kiem khong duoc de trong", 400);
        }
        return messageRepository
                .searchVisibleByConversation(conversationId, userId, query.trim(), pageable)
                .map(responseMapper::toMessageResponse);
    }

    @Transactional(readOnly = true)
    public Page<MessageResponse> getGallery(UUID conversationId, UUID userId, String type, Pageable pageable) {
        ensureMember(conversationId, userId);
        String normalized = type == null ? "MEDIA" : type.trim().toUpperCase(Locale.ROOT);
        if ("LINKS".equals(normalized)) {
            return messageRepository.findVisibleLinks(conversationId, userId, pageable)
                    .map(responseMapper::toMessageResponse);
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
                .map(responseMapper::toMessageResponse);
    }

    @Transactional
    public MessageResponse sendMessage(UUID conversationId, SendMessageRequest request, UUID senderId) {
        ConversationMember sender = ensureMember(conversationId, senderId);
        permissionPolicy.ensureCanChat(sender);
        MessageType messageType = requestValidator.parseMessageType(request.messageType());
        requestValidator.validateMessageBody(request.content(), request.mediaUrl(), messageType);

        UUID parentMessageId = request.parentMessageId();
        if (parentMessageId != null) {
            Message parent = messageRepository.findById(parentMessageId)
                    .orElseThrow(() -> new com.suachuabientan.system_internal.common.exception.BusinessException("Khong tim thay tin nhan nguoi dung muon tra loi", 404));
            if (!parent.getConversationId().equals(conversationId)) {
                throw new com.suachuabientan.system_internal.common.exception.BusinessException("Tin nhan duoc tra loi phai thuoc cung cuoc tro chuyen", 400);
            }
        }

        Message message = Message.builder()
                .conversationId(conversationId)
                .senderId(senderId)
                .content(request.content())
                .mediaUrl(request.mediaUrl())
                .messageType(messageType)
                .sentAt(Instant.now())
                .parentMessageId(parentMessageId)
                .build();

        Message saved = messageRepository.save(message);
        saveMentions(saved.getId(), conversationId, request.mentionUserIds());
        markMessageRead(saved.getId(), senderId);
        conversationRepository.findByIdAndIsDeletedFalse(conversationId)
                .ifPresent(conversationRepository::save);

        MessageResponse response = responseMapper.toMessageResponse(saved);
        realtimePublisher.publishMessage(response, senderId);
        realtimePublisher.notifyMembers(response, senderId);
        return response;
    }

    @Transactional
    public MessageResponse sendMediaMessage(
            UUID conversationId,
            MultipartFile file,
            String content,
            String type,
            UUID parentMessageId,
            UUID senderId) {
        ensureMember(conversationId, senderId);
        MessageType messageType = requestValidator.parseMessageType(type);
        requestValidator.validateUploadableMediaType(messageType, type);

        MessageMediaStorageService.StoredMedia stored = messageMediaStorageService.store(file, messageType);
        String effectiveContent = StringUtils.hasText(content)
                ? content.trim()
                : (messageType == MessageType.FILE ? stored.originalFileName() : null);
        return sendMessage(
                conversationId,
                new SendMessageRequest(effectiveContent, stored.publicUrl(), messageType.name(), null, parentMessageId),
                senderId);
    }

    @Transactional
    public MessageResponse sendMessage(SendMessageWSRequest request, UUID senderId) {
        SendMessageRequest restRequest = new SendMessageRequest(
                request.content(),
                request.mediaUrl(),
                request.messageType(),
                null,
                request.parentMessageId());
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
        MessageResponse response = responseMapper.toMessageResponse(saved);
        realtimePublisher.publishConversationEvent(conversationId, "MESSAGE_UPDATED", response);
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
            return responseMapper.toMessageResponse(message);
        }
        if (!"EVERYONE".equals(normalizedScope)) {
            throw new BusinessException("Pham vi xoa tin nhan khong hop le", 400);
        }
        if (!message.getSenderId().equals(requesterId) && !permissionPolicy.canModerate(requester)) {
            throw new BusinessException("Chi nguoi gui hoac quan tri vien moi duoc thu hoi tin nhan", 403);
        }

        message.setDeletedForEveryoneAt(Instant.now());
        message.setDeletedByUserId(requesterId);
        Message saved = messageRepository.save(message);
        MessageResponse response = responseMapper.toMessageResponse(saved);
        realtimePublisher.publishConversationEvent(conversationId, "MESSAGE_DELETED", response);
        return response;
    }

    @Transactional
    public MessageResponse addReaction(UUID conversationId, UUID messageId, String emoji, UUID userId) {
        ensureMember(conversationId, userId);
        Message message = findMessage(conversationId, messageId);
        String normalizedEmoji = requestValidator.normalizeEmoji(emoji);
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
        MessageResponse response = responseMapper.toMessageResponse(message);
        realtimePublisher.publishConversationEvent(conversationId, "MESSAGE_REACTION_UPDATED", response);
        return response;
    }

    @Transactional
    public MessageResponse removeReaction(UUID conversationId, UUID messageId, String emoji, UUID userId) {
        ensureMember(conversationId, userId);
        Message message = findMessage(conversationId, messageId);
        messageReactionRepository.deleteByMessageIdAndUserIdAndEmoji(
                messageId,
                userId,
                requestValidator.normalizeEmoji(emoji));
        MessageResponse response = responseMapper.toMessageResponse(message);
        realtimePublisher.publishConversationEvent(conversationId, "MESSAGE_REACTION_UPDATED", response);
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

        ConversationMemberRole role = requestValidator.parseMemberRole(request.role());
        target.setRole(role);
        target.setIsAdmin(role == ConversationMemberRole.ADMIN);
        if (request.canChat() != null) {
            target.setCanChat(request.canChat());
            target.setBannedAt(Boolean.FALSE.equals(request.canChat()) ? Instant.now() : null);
        }
        conversationMemberRepository.save(target);
        return responseMapper.toConversationResponse(conversation, requester.getUserId());
    }

    @Transactional
    public ConversationResponse setConversationPinned(UUID conversationId, UUID userId, boolean pinned) {
        Conversation conversation = conversationRepository.findByIdAndIsDeletedFalse(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay cuoc tro chuyen: " + conversationId));
        ConversationMember member = ensureMember(conversationId, userId);
        member.setPinnedAt(pinned ? Instant.now() : null);
        conversationMemberRepository.save(member);
        return responseMapper.toConversationResponse(conversation, userId);
    }

    @Transactional
    public ConversationResponse setNotificationsMuted(UUID conversationId, UUID userId, boolean muted) {
        Conversation conversation = conversationRepository.findByIdAndIsDeletedFalse(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay cuoc tro chuyen: " + conversationId));
        ConversationMember member = ensureMember(conversationId, userId);
        member.setNotificationsMuted(muted);
        conversationMemberRepository.save(member);
        return responseMapper.toConversationResponse(conversation, userId);
    }

    @Transactional
    public ConversationResponse pinMessage(UUID conversationId, UUID messageId, UUID requesterId) {
        Conversation conversation = conversationRepository.findByIdAndIsDeletedFalse(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay cuoc tro chuyen: " + conversationId));
        ConversationMember requester = ensureMember(conversationId, requesterId);
        if (conversation.getType() == ConversationType.GROUP && !permissionPolicy.canModerate(requester)) {
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
        ConversationResponse response = responseMapper.toConversationResponse(saved, requesterId);
        realtimePublisher.publishConversationEvent(conversationId, "PINNED_MESSAGE_UPDATED", response);
        return response;
    }

    @Transactional
    public ConversationResponse unpinMessage(UUID conversationId, UUID requesterId) {
        Conversation conversation = conversationRepository.findByIdAndIsDeletedFalse(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay cuoc tro chuyen: " + conversationId));
        ConversationMember requester = ensureMember(conversationId, requesterId);
        if (conversation.getType() == ConversationType.GROUP && !permissionPolicy.canModerate(requester)) {
            throw new BusinessException("Chi admin hoac moderator moi duoc bo ghim tin nhan nhom", 403);
        }

        conversation.setPinnedMessageId(null);
        conversation.setPinnedMessageAt(null);
        conversation.setPinnedMessageBy(null);
        Conversation saved = conversationRepository.save(conversation);
        ConversationResponse response = responseMapper.toConversationResponse(saved, requesterId);
        realtimePublisher.publishConversationEvent(conversationId, "PINNED_MESSAGE_UPDATED", response);
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
        realtimePublisher.publishConversationEvent(conversationId, "TYPING", event);
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
        return responseMapper.toConversationResponse(conversation, requesterId);
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

        return responseMapper.toConversationResponse(conversationRepository.save(conversation), requesterId);
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
        return responseMapper.toConversationResponse(conversation, requesterId);
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

}
