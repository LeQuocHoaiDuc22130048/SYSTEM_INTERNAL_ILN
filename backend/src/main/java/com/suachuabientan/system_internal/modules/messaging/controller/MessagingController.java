package com.suachuabientan.system_internal.modules.messaging.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.messaging.dto.request.AddConversationMembersRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.request.CreateConversationRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.request.DeleteMessageRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.request.MessageReactionRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.request.SendMessageRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.request.TypingRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.request.UpdateConversationRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.request.UpdateMemberRoleRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.request.UpdateMessageRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.response.ConversationResponse;
import com.suachuabientan.system_internal.modules.messaging.dto.response.MessageResponse;
import com.suachuabientan.system_internal.modules.messaging.service.MessagingService;
import com.suachuabientan.system_internal.security.authorization.RoleExpressions;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

@Tag(name = "Messaging", description = "Internal realtime messaging")
@RestController
@RequestMapping("/api/v1/conversations")
@RequiredArgsConstructor
@PreAuthorize(RoleExpressions.ANY_ACTIVE_USER)
public class MessagingController {
    private final MessagingService messagingService;

    @Operation(summary = "List my conversations")
    @GetMapping
    public ResponseEntity<ApiResponse<List<ConversationResponse>>> getMyConversations(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.getMyConversations(userDetails.getUserId())));
    }

    @Operation(summary = "Create direct or group conversation")
    @PostMapping
    public ResponseEntity<ApiResponse<ConversationResponse>> createConversation(
            @Valid @RequestBody CreateConversationRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.status(201).body(ApiResponse.created(
                messagingService.createConversation(request, userDetails.getUserId())));
    }

    @Operation(summary = "Get conversation messages")
    @GetMapping("/{conversationId}/messages")
    public ResponseEntity<ApiResponse<Page<MessageResponse>>> getMessages(
            @PathVariable UUID conversationId,
            @PageableDefault(size = 30) Pageable pageable,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.getMessages(conversationId, userDetails.getUserId(), pageable)));
    }

    @Operation(summary = "Search messages in conversation")
    @GetMapping("/{conversationId}/messages/search")
    public ResponseEntity<ApiResponse<Page<MessageResponse>>> searchMessages(
            @PathVariable UUID conversationId,
            @RequestParam String query,
            @PageableDefault(size = 30) Pageable pageable,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.searchMessages(conversationId, userDetails.getUserId(), query, pageable)));
    }

    @Operation(summary = "Get conversation media, links, and file gallery")
    @GetMapping("/{conversationId}/gallery")
    public ResponseEntity<ApiResponse<Page<MessageResponse>>> getGallery(
            @PathVariable UUID conversationId,
            @RequestParam(defaultValue = "MEDIA") String type,
            @PageableDefault(size = 50) Pageable pageable,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.getGallery(conversationId, userDetails.getUserId(), type, pageable)));
    }

    @Operation(summary = "Send message")
    @PostMapping("/{conversationId}/messages")
    public ResponseEntity<ApiResponse<MessageResponse>> sendMessage(
            @PathVariable UUID conversationId,
            @Valid @RequestBody SendMessageRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.status(201).body(ApiResponse.created(
                messagingService.sendMessage(conversationId, request, userDetails.getUserId())));
    }

    @Operation(summary = "Send media message")
    @PostMapping(value = "/{conversationId}/messages/media", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<MessageResponse>> sendMediaMessage(
            @PathVariable UUID conversationId,
            @RequestPart("file") MultipartFile file,
            @RequestParam(required = false) String content,
            @RequestParam String messageType,
            @RequestParam(required = false) UUID parentMessageId,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.status(201).body(ApiResponse.created(
                messagingService.sendMediaMessage(
                        conversationId,
                        file,
                        content,
                        messageType,
                        parentMessageId,
                        userDetails.getUserId())));
    }

    @Operation(summary = "Edit sent message")
    @PatchMapping("/{conversationId}/messages/{messageId}")
    public ResponseEntity<ApiResponse<MessageResponse>> updateMessage(
            @PathVariable UUID conversationId,
            @PathVariable UUID messageId,
            @Valid @RequestBody UpdateMessageRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.updateMessage(conversationId, messageId, request, userDetails.getUserId()),
                "Da cap nhat tin nhan"));
    }

    @Operation(summary = "Delete message for me or recall for everyone")
    @DeleteMapping("/{conversationId}/messages/{messageId}")
    public ResponseEntity<ApiResponse<MessageResponse>> deleteMessage(
            @PathVariable UUID conversationId,
            @PathVariable UUID messageId,
            @Valid @RequestBody DeleteMessageRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.deleteMessage(
                        conversationId,
                        messageId,
                        request.scope(),
                        userDetails.getUserId()),
                "Da xoa tin nhan"));
    }

    @Operation(summary = "Add message reaction")
    @PutMapping("/{conversationId}/messages/{messageId}/reactions")
    public ResponseEntity<ApiResponse<MessageResponse>> addReaction(
            @PathVariable UUID conversationId,
            @PathVariable UUID messageId,
            @Valid @RequestBody MessageReactionRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.addReaction(
                        conversationId,
                        messageId,
                        request.emoji(),
                        userDetails.getUserId()),
                "Da tha cam xuc"));
    }

    @Operation(summary = "Remove message reaction")
    @DeleteMapping("/{conversationId}/messages/{messageId}/reactions")
    public ResponseEntity<ApiResponse<MessageResponse>> removeReaction(
            @PathVariable UUID conversationId,
            @PathVariable UUID messageId,
            @Valid @RequestBody MessageReactionRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.removeReaction(
                        conversationId,
                        messageId,
                        request.emoji(),
                        userDetails.getUserId()),
                "Da go cam xuc"));
    }

    @Operation(summary = "Pin conversation for current user")
    @PutMapping("/{conversationId}/pin")
    public ResponseEntity<ApiResponse<ConversationResponse>> pinConversation(
            @PathVariable UUID conversationId,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.setConversationPinned(conversationId, userDetails.getUserId(), true),
                "Da ghim cuoc tro chuyen"));
    }

    @Operation(summary = "Unpin conversation for current user")
    @DeleteMapping("/{conversationId}/pin")
    public ResponseEntity<ApiResponse<ConversationResponse>> unpinConversation(
            @PathVariable UUID conversationId,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.setConversationPinned(conversationId, userDetails.getUserId(), false),
                "Da bo ghim cuoc tro chuyen"));
    }

    @Operation(summary = "Mute notifications for conversation")
    @PutMapping("/{conversationId}/mute")
    public ResponseEntity<ApiResponse<ConversationResponse>> muteConversation(
            @PathVariable UUID conversationId,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.setNotificationsMuted(conversationId, userDetails.getUserId(), true),
                "Da tat thong bao cuoc tro chuyen"));
    }

    @Operation(summary = "Unmute notifications for conversation")
    @DeleteMapping("/{conversationId}/mute")
    public ResponseEntity<ApiResponse<ConversationResponse>> unmuteConversation(
            @PathVariable UUID conversationId,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.setNotificationsMuted(conversationId, userDetails.getUserId(), false),
                "Da bat thong bao cuoc tro chuyen"));
    }

    @Operation(summary = "Pin message to conversation")
    @PutMapping("/{conversationId}/pinned-message/{messageId}")
    public ResponseEntity<ApiResponse<ConversationResponse>> pinMessage(
            @PathVariable UUID conversationId,
            @PathVariable UUID messageId,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.pinMessage(conversationId, messageId, userDetails.getUserId()),
                "Da ghim tin nhan"));
    }

    @Operation(summary = "Unpin message from conversation")
    @DeleteMapping("/{conversationId}/pinned-message")
    public ResponseEntity<ApiResponse<ConversationResponse>> unpinMessage(
            @PathVariable UUID conversationId,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.unpinMessage(conversationId, userDetails.getUserId()),
                "Da bo ghim tin nhan"));
    }

    @Operation(summary = "Add members")
    @PostMapping("/{conversationId}/members")
    public ResponseEntity<ApiResponse<ConversationResponse>> addMembers(
            @PathVariable UUID conversationId,
            @Valid @RequestBody AddConversationMembersRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.addMembers(conversationId, request.memberIds(), userDetails.getUserId()),
                "Da them thanh vien"));
    }

    @Operation(summary = "Update conversation")
    @PatchMapping("/{conversationId}")
    public ResponseEntity<ApiResponse<ConversationResponse>> updateConversation(
            @PathVariable UUID conversationId,
            @Valid @RequestBody UpdateConversationRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.updateConversation(conversationId, request, userDetails.getUserId()),
                "Da cap nhat cuoc tro chuyen"));
    }

    @Operation(summary = "Update member role and chat permission")
    @PatchMapping("/{conversationId}/members/{memberId}/role")
    public ResponseEntity<ApiResponse<ConversationResponse>> updateMemberRole(
            @PathVariable UUID conversationId,
            @PathVariable UUID memberId,
            @Valid @RequestBody UpdateMemberRoleRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.updateMemberRole(conversationId, memberId, request, userDetails.getUserId()),
                "Da cap nhat vai tro thanh vien"));
    }

    @Operation(summary = "Remove member")
    @DeleteMapping("/{conversationId}/members/{memberId}")
    public ResponseEntity<ApiResponse<ConversationResponse>> removeMember(
            @PathVariable UUID conversationId,
            @PathVariable UUID memberId,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.removeMember(conversationId, memberId, userDetails.getUserId()),
                "Da xoa thanh vien"));
    }

    @Operation(summary = "Publish typing state")
    @PostMapping("/{conversationId}/typing")
    public ResponseEntity<ApiResponse<Void>> typing(
            @PathVariable UUID conversationId,
            @RequestBody(required = false) TypingRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        messagingService.publishTyping(
                conversationId,
                userDetails.getUserId(),
                request != null && Boolean.TRUE.equals(request.typing()));
        return ResponseEntity.ok(ApiResponse.success(null, "Da cap nhat typing"));
    }

    @Operation(summary = "Leave group conversation")
    @PostMapping("/{conversationId}/leave")
    public ResponseEntity<ApiResponse<Void>> leaveConversation(
            @PathVariable UUID conversationId,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        messagingService.leaveConversation(conversationId, userDetails.getUserId());
        return ResponseEntity.ok(ApiResponse.success(null, "Da roi khoi cuoc tro chuyen"));
    }

    @Operation(summary = "Mark conversation as read")
    @PutMapping("/{conversationId}/read")
    public ResponseEntity<ApiResponse<Void>> markAsRead(
            @PathVariable UUID conversationId,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        messagingService.markAsRead(conversationId, userDetails.getUserId());
        return ResponseEntity.ok(ApiResponse.success(null, "Da danh dau da doc"));
    }
}
