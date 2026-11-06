package com.suachuabientan.system_internal.modules.customer.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerFeedbackResponse;
import com.suachuabientan.system_internal.modules.customer.dto.ReplyCustomerFeedbackRequest;
import com.suachuabientan.system_internal.modules.customer.service.CustomerFeedbackService;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@Tag(name = "Customer Feedback Management", description = "Quản lý và tiếp nhận phản hồi, đánh giá CSKH của khách hàng")
@RestController
@RequestMapping("/api/v1/customers/feedbacks")
@RequiredArgsConstructor
public class CustomerFeedbackController {

    private final CustomerFeedbackService feedbackService;

    @Operation(summary = "Xem danh sách phản hồi từ khách hàng")
    @GetMapping
    @PreAuthorize("hasAuthority('CUSTOMER_VIEW') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<Page<CustomerFeedbackResponse>>> getAll(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) Boolean isUrgent,
            @RequestParam(required = false) UUID customerId,
            @PageableDefault(size = 50) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(
                feedbackService.getAllFeedbacks(keyword, status, type, isUrgent, customerId, pageable)
        ));
    }

    @Operation(summary = "Kỹ sư / CSKH trả lời và cập nhật tiến độ giải quyết")
    @PutMapping("/{id}/reply")
    @PreAuthorize("hasAuthority('CUSTOMER_MANAGE') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<CustomerFeedbackResponse>> replyFeedback(
            @PathVariable UUID id,
            @Valid @RequestBody ReplyCustomerFeedbackRequest request,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        String defaultReplier = userDetails != null && userDetails.getUsername() != null && !userDetails.getUsername().isBlank()
                ? userDetails.getUsername()
                : "Kỹ sư LikeNew";
        return ResponseEntity.ok(ApiResponse.success(
                feedbackService.replyFeedback(id, request, defaultReplier),
                "Đã gửi phản hồi thành công"
        ));
    }

    @Operation(summary = "Cập nhật trạng thái xử lý phản hồi")
    @PatchMapping("/{id}/status")
    @PreAuthorize("hasAuthority('CUSTOMER_MANAGE') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ApiResponse<CustomerFeedbackResponse>> updateStatus(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body) {
        String status = body.getOrDefault("status", "IN_PROGRESS");
        return ResponseEntity.ok(ApiResponse.success(
                feedbackService.updateStatus(id, status),
                "Cập nhật trạng thái thành công"
        ));
    }
}
