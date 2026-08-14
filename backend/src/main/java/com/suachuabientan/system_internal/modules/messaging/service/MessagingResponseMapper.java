package com.suachuabientan.system_internal.modules.messaging.service;

import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.messaging.dto.response.ConversationResponse;
import com.suachuabientan.system_internal.modules.messaging.dto.response.MessageResponse;
import com.suachuabientan.system_internal.modules.messaging.entity.Conversation;
import com.suachuabientan.system_internal.modules.messaging.entity.ConversationMember;
import com.suachuabientan.system_internal.modules.messaging.entity.Message;
import com.suachuabientan.system_internal.modules.messaging.entity.MessageMention;
import com.suachuabientan.system_internal.modules.messaging.entity.MessageReaction;
import com.suachuabientan.system_internal.modules.messaging.entity.MessageRead;
import com.suachuabientan.system_internal.modules.messaging.enums.ConversationMemberRole;
import com.suachuabientan.system_internal.modules.messaging.enums.ConversationType;
import com.suachuabientan.system_internal.modules.messaging.enums.MessageType;
import com.suachuabientan.system_internal.modules.messaging.repository.ConversationMemberRepository;
import com.suachuabientan.system_internal.modules.messaging.repository.MessageMentionRepository;
import com.suachuabientan.system_internal.modules.messaging.repository.MessageReactionRepository;
import com.suachuabientan.system_internal.modules.messaging.repository.MessageReadRepository;
import com.suachuabientan.system_internal.modules.messaging.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

@Component
@RequiredArgsConstructor
public class MessagingResponseMapper {
    private final ConversationMemberRepository conversationMemberRepository;
    private final MessageRepository messageRepository;
    private final MessageReadRepository messageReadRepository;
    private final MessageReactionRepository messageReactionRepository;
    private final MessageMentionRepository messageMentionRepository;
    private final UserRepository userRepository;

    public ConversationResponse toConversationResponse(Conversation conversation, UUID viewerId) {
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
                viewerMember == null ? 0 : unreadCount(conversation.getId(), viewerId, viewerMember),
                conversation.getCreatedAt()
        );
    }

    public MessageResponse toMessageResponse(Message message) {
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

        MessageResponse.ParentMessageInfo parentMessageInfo = null;
        if (message.getParentMessageId() != null) {
            Message parent = messageRepository.findById(message.getParentMessageId()).orElse(null);
            if (parent != null && !Boolean.TRUE.equals(parent.getIsDeleted())) {
                UserEntity parentSender = findUser(parent.getSenderId());
                boolean parentRecalled = parent.getDeletedForEveryoneAt() != null;
                parentMessageInfo = new MessageResponse.ParentMessageInfo(
                        parent.getId(),
                        parentSender.getFullName(),
                        parentRecalled ? "Tin nhan da duoc thu hoi" : parent.getContent(),
                        parentRecalled ? MessageType.SYSTEM.name() : parent.getMessageType().name(),
                        parent.getDeletedForEveryoneAt()
                );
            }
        }

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
                reactions,
                message.getParentMessageId(),
                parentMessageInfo
        );
    }

    private long unreadCount(UUID conversationId, UUID viewerId, ConversationMember viewerMember) {
        return viewerMember.getLastReadAt() == null
                ? messageRepository.countUnread(conversationId, viewerId)
                : messageRepository.countUnreadAfter(conversationId, viewerId, viewerMember.getLastReadAt());
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
                user != null ? user.getFullName() : "Khong xac dinh",
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
                sender != null ? sender.getFullName() : "Khong xac dinh",
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

    private UserEntity findUser(UUID userId) {
        return userRepository.findByIdAndIsDeletedFalse(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay nguoi dung: " + userId));
    }
}
