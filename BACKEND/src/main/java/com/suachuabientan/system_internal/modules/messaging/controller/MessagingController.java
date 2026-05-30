package com.suachuabientan.system_internal.modules.messaging.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.messaging.dto.request.AddConversationMembersRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.request.CreateConversationRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.request.SendMessageRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.request.UpdateConversationRequest;
import com.suachuabientan.system_internal.modules.messaging.dto.response.ConversationResponse;
import com.suachuabientan.system_internal.modules.messaging.dto.response.MessageResponse;
import com.suachuabientan.system_internal.modules.messaging.service.MessagingService;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

@Tag(name = "Messaging", description = "Nhắn tin nội bộ realtime")
@RestController
@RequestMapping("/api/v1/conversations")
@RequiredArgsConstructor
public class MessagingController {
    private final MessagingService messagingService;

    @Operation(summary = "Danh sach cuoc tro chuyen cua nguoi dang dang nhap")
    @GetMapping
    public ResponseEntity<ApiResponse<List<ConversationResponse>>> getMyConversations(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.getMyConversations(userDetails.getUserId())));
    }

    @Operation(summary = "Tao cuoc tro chuyen direct hoac group")
    @PostMapping
    public ResponseEntity<ApiResponse<ConversationResponse>> createConversation(
            @Valid @RequestBody CreateConversationRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.status(201).body(ApiResponse.created(
                messagingService.createConversation(request, userDetails.getUserId())));
    }

    @Operation(summary = "Lich su tin nhan trong cuoc tro chuyen")
    @GetMapping("/{conversationId}/messages")
    public ResponseEntity<ApiResponse<Page<MessageResponse>>> getMessages(
            @PathVariable UUID conversationId,
            @PageableDefault(size = 30) Pageable pageable,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.getMessages(conversationId, userDetails.getUserId(), pageable)));
    }

    @Operation(summary = "Gui tin nhan vao cuoc tro chuyen")
    @PostMapping("/{conversationId}/messages")
    public ResponseEntity<ApiResponse<MessageResponse>> sendMessage(
            @PathVariable UUID conversationId,
            @Valid @RequestBody SendMessageRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.status(201).body(ApiResponse.created(
                messagingService.sendMessage(conversationId, request, userDetails.getUserId())));
    }

    @Operation(summary = "Gui anh, video hoac tep dinh kem vao cuoc tro chuyen")
    @PostMapping(value = "/{conversationId}/messages/media", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<MessageResponse>> sendMediaMessage(
            @PathVariable UUID conversationId,
            @RequestPart("file") MultipartFile file,
            @RequestParam(required = false) String content,
            @RequestParam String messageType,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.status(201).body(ApiResponse.created(
                messagingService.sendMediaMessage(
                        conversationId,
                        file,
                        content,
                        messageType,
                        userDetails.getUserId())));
    }

    @Operation(summary = "Them thanh vien vao nhom")
    @PostMapping("/{conversationId}/members")
    public ResponseEntity<ApiResponse<ConversationResponse>> addMembers(
            @PathVariable UUID conversationId,
            @Valid @RequestBody AddConversationMembersRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.addMembers(conversationId, request.memberIds(), userDetails.getUserId()),
                "Da them thanh vien vao cuoc tro chuyen"));
    }

    @Operation(summary = "Cap nhat thong tin nhom")
    @PatchMapping("/{conversationId}")
    public ResponseEntity<ApiResponse<ConversationResponse>> updateConversation(
            @PathVariable UUID conversationId,
            @Valid @RequestBody UpdateConversationRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.updateConversation(conversationId, request, userDetails.getUserId()),
                "Da cap nhat cuoc tro chuyen"));
    }

    @Operation(summary = "Xoa thanh vien khoi nhom")
    @DeleteMapping("/{conversationId}/members/{memberId}")
    public ResponseEntity<ApiResponse<ConversationResponse>> removeMember(
            @PathVariable UUID conversationId,
            @PathVariable UUID memberId,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                messagingService.removeMember(conversationId, memberId, userDetails.getUserId()),
                "Da xoa thanh vien khoi cuoc tro chuyen"));
    }

    @Operation(summary = "Roi khoi nhom")
    @PostMapping("/{conversationId}/leave")
    public ResponseEntity<ApiResponse<Void>> leaveConversation(
            @PathVariable UUID conversationId,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        messagingService.leaveConversation(conversationId, userDetails.getUserId());
        return ResponseEntity.ok(ApiResponse.success(null, "Da roi khoi cuoc tro chuyen"));
    }

    @Operation(summary = "Danh dau da doc cuoc tro chuyen")
    @PutMapping("/{conversationId}/read")
    public ResponseEntity<ApiResponse<Void>> markAsRead(
            @PathVariable UUID conversationId,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        messagingService.markAsRead(conversationId, userDetails.getUserId());
        return ResponseEntity.ok(ApiResponse.success(null, "Da danh dau cuoc tro chuyen la da doc"));
    }
}
