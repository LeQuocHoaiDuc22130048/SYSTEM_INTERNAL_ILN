package com.suachuabientan.system_internal.modules.messaging.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.modules.messaging.enums.ConversationMemberRole;
import com.suachuabientan.system_internal.modules.messaging.enums.ConversationType;
import com.suachuabientan.system_internal.modules.messaging.enums.MessageType;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

@Component
public class MessagingRequestValidator {
    private static final Set<String> SUPPORTED_REACTIONS = Set.of(
            "\uD83D\uDC4D",
            "\u2764\uFE0F",
            "\uD83D\uDE02",
            "\uD83D\uDE2E",
            "\uD83D\uDE22",
            "\uD83D\uDE21"
    );

    public ConversationType parseConversationType(String value) {
        try {
            return ConversationType.valueOf(normalizeEnumValue(value));
        } catch (Exception ex) {
            throw new BusinessException("Loai cuoc tro chuyen khong hop le: " + value);
        }
    }

    public MessageType parseMessageType(String value) {
        try {
            return MessageType.valueOf(normalizeEnumValue(value));
        } catch (Exception ex) {
            throw new BusinessException("Loai tin nhan khong hop le: " + value);
        }
    }

    public ConversationMemberRole parseMemberRole(String value) {
        try {
            return ConversationMemberRole.valueOf(normalizeEnumValue(value));
        } catch (Exception error) {
            throw new BusinessException("Vai tro thanh vien khong hop le: " + value, 400);
        }
    }

    public String normalizeEmoji(String emoji) {
        String normalized = emoji == null ? "" : emoji.trim();
        if (!SUPPORTED_REACTIONS.contains(normalized)) {
            throw new BusinessException("Emoji reaction khong duoc ho tro", 400);
        }
        return normalized;
    }

    public List<UUID> normalizeMemberIds(List<UUID> memberIds, UUID creatorId) {
        List<UUID> normalized = new ArrayList<>(memberIds != null ? memberIds : List.of());
        normalized.add(creatorId);
        return normalized.stream().distinct().toList();
    }

    public void validateConversationRequest(
            ConversationType type,
            String name,
            List<UUID> memberIds,
            UUID creatorId) {
        if (type == ConversationType.DIRECT && memberIds.size() != 2) {
            throw new BusinessException("Cuoc tro chuyen DIRECT can co 2 thanh vien");
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

    public void validateMessageBody(String content, String mediaUrl, MessageType messageType) {
        if (messageType == MessageType.TEXT && !StringUtils.hasText(content)) {
            throw new BusinessException("Tin nhan TEXT phai co noi dung");
        }
        if (isMediaMessage(messageType) && !StringUtils.hasText(mediaUrl)) {
            throw new BusinessException("Tin nhan media phai co mediaUrl");
        }
    }

    public void validateUploadableMediaType(MessageType messageType, String rawType) {
        if (messageType != MessageType.IMAGE
                && messageType != MessageType.VIDEO
                && messageType != MessageType.FILE) {
            throw new BusinessException("Loai tin nhan upload khong hop le: " + rawType);
        }
    }

    private boolean isMediaMessage(MessageType messageType) {
        return messageType == MessageType.IMAGE
                || messageType == MessageType.VIDEO
                || messageType == MessageType.FILE
                || messageType == MessageType.STICKER
                || messageType == MessageType.GIF;
    }

    private String normalizeEnumValue(String value) {
        return value == null ? "" : value.trim().toUpperCase(Locale.ROOT);
    }
}
