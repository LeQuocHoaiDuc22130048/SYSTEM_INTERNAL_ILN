package com.suachuabientan.system_internal.modules.messaging.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.modules.messaging.entity.ConversationMember;
import com.suachuabientan.system_internal.modules.messaging.enums.ConversationMemberRole;
import org.springframework.stereotype.Component;

import java.time.Instant;

@Component
public class MessagingPermissionPolicy {
    public void ensureCanChat(ConversationMember member) {
        if (Boolean.FALSE.equals(member.getCanChat()) || member.getBannedAt() != null) {
            throw new BusinessException("Ban dang bi cam chat trong cuoc tro chuyen nay", 403);
        }
        if (member.getMutedUntil() != null && member.getMutedUntil().isAfter(Instant.now())) {
            throw new BusinessException("Ban dang bi tam khoa chat den " + member.getMutedUntil(), 403);
        }
    }

    public boolean canModerate(ConversationMember member) {
        ConversationMemberRole role = member.getRole();
        return role == ConversationMemberRole.ADMIN || role == ConversationMemberRole.MODERATOR;
    }
}
