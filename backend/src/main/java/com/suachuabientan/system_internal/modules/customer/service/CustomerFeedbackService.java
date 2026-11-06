package com.suachuabientan.system_internal.modules.customer.service;

import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.customer.dto.CreateCustomerFeedbackRequest;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerFeedbackResponse;
import com.suachuabientan.system_internal.modules.customer.dto.ReplyCustomerFeedbackRequest;
import com.suachuabientan.system_internal.modules.customer.entity.Customer;
import com.suachuabientan.system_internal.modules.customer.entity.CustomerAccount;
import com.suachuabientan.system_internal.modules.customer.entity.CustomerFeedback;
import com.suachuabientan.system_internal.modules.customer.repository.CustomerAccountRepository;
import com.suachuabientan.system_internal.modules.customer.repository.CustomerFeedbackRepository;
import com.suachuabientan.system_internal.modules.customer.repository.CustomerRepository;
import jakarta.persistence.criteria.Predicate;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class CustomerFeedbackService {

    private final CustomerFeedbackRepository feedbackRepository;
    private final CustomerAccountRepository customerAccountRepository;
    private final CustomerRepository customerRepository;
    private final UserRepository userRepository;

    @Transactional
    public CustomerFeedbackResponse createFeedback(UUID userId, CreateCustomerFeedbackRequest request) {
        final CustomerFeedback feedback = new CustomerFeedback();
        feedback.setOrderCode(request.getOrderCode() != null && !request.getOrderCode().isBlank() ? request.getOrderCode() : "Ý kiến chung");
        feedback.setDeviceModel(request.getDeviceModel());
        feedback.setRating(request.getRating());
        feedback.setType(request.getType() != null ? request.getType() : "SERVICE_QUALITY");

        String typeName = request.getTypeName();
        if (typeName == null || typeName.isBlank()) {
            if ("WARRANTY_ISSUE".equalsIgnoreCase(request.getType())) {
                typeName = "Khiếu nại / Bảo hành";
            } else if ("SUGGESTION".equalsIgnoreCase(request.getType())) {
                typeName = "Đóng góp ý kiến";
            } else {
                typeName = "Đánh giá chất lượng";
            }
        }
        feedback.setTypeName(typeName);

        if (request.getTags() != null && !request.getTags().isEmpty()) {
            feedback.setTags(String.join(",", request.getTags()));
        }
        feedback.setContent(request.getContent());

        if (request.getImages() != null && !request.getImages().isEmpty()) {
            feedback.setImages(String.join(",", request.getImages()));
        }

        feedback.setUrgent(request.isUrgent());
        feedback.setStatus("PENDING");
        feedback.setStatusName("Chờ tiếp nhận");

        // Resolve Customer Info
        Optional<CustomerAccount> accountOpt = customerAccountRepository.findByUserIdAndActiveTrueAndIsDeletedFalse(userId);
        if (accountOpt.isPresent()) {
            CustomerAccount account = accountOpt.get();
            feedback.setCustomerId(account.getCustomerId());
            customerRepository.findByIdAndIsDeletedFalse(account.getCustomerId()).ifPresent(c -> {
                feedback.setCustomerName(c.getCustomerName());
                feedback.setCustomerCode(c.getCustomerCode());
                feedback.setCustomerPhone(c.getPhone());
            });
        }

        if (feedback.getCustomerName() == null || feedback.getCustomerName().isBlank()) {
            userRepository.findByIdAndIsDeletedFalse(userId).ifPresent(u -> {
                feedback.setCustomerName(u.getFullName() != null && !u.getFullName().isBlank() ? u.getFullName() : u.getUsername());
                feedback.setCustomerPhone(u.getPhone());
            });
        }

        if (feedback.getCustomerName() == null || feedback.getCustomerName().isBlank()) {
            feedback.setCustomerName("Khách hàng LikeNew");
        }

        CustomerFeedback saved = feedbackRepository.save(feedback);
        return mapToResponse(saved);
    }

    @Transactional(readOnly = true)
    public Page<CustomerFeedbackResponse> getMyFeedbacks(UUID userId, Pageable pageable) {
        Optional<CustomerAccount> accountOpt = customerAccountRepository.findByUserIdAndActiveTrueAndIsDeletedFalse(userId);
        if (accountOpt.isPresent()) {
            return feedbackRepository.findByCustomerIdAndIsDeletedFalseOrderByCreatedAtDesc(accountOpt.get().getCustomerId(), pageable)
                    .map(this::mapToResponse);
        }

        // If no customer account linked, search by createdBy
        Specification<CustomerFeedback> spec = (root, query, cb) ->
                cb.and(cb.equal(root.get("isDeleted"), false), cb.equal(root.get("createdBy"), userId));

        return feedbackRepository.findAll(spec, pageable).map(this::mapToResponse);
    }

    @Transactional(readOnly = true)
    public Page<CustomerFeedbackResponse> getAllFeedbacks(
            String keyword,
            String status,
            String type,
            Boolean isUrgent,
            UUID customerId,
            Pageable pageable) {

        Specification<CustomerFeedback> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(cb.equal(root.get("isDeleted"), false));

            if (status != null && !status.isBlank() && !"ALL".equalsIgnoreCase(status)) {
                predicates.add(cb.equal(root.get("status"), status));
            }

            if (type != null && !type.isBlank() && !"ALL".equalsIgnoreCase(type)) {
                predicates.add(cb.equal(root.get("type"), type));
            }

            if (isUrgent != null) {
                predicates.add(cb.equal(root.get("isUrgent"), isUrgent));
            }

            if (customerId != null) {
                predicates.add(cb.equal(root.get("customerId"), customerId));
            }

            if (keyword != null && !keyword.isBlank()) {
                String pattern = "%" + keyword.toLowerCase().trim() + "%";
                Predicate matchName = cb.like(cb.lower(root.get("customerName")), pattern);
                Predicate matchOrder = cb.like(cb.lower(root.get("orderCode")), pattern);
                Predicate matchDevice = cb.like(cb.lower(root.get("deviceModel")), pattern);
                Predicate matchContent = cb.like(cb.lower(root.get("content")), pattern);
                Predicate matchCode = cb.like(cb.lower(root.get("customerCode")), pattern);
                predicates.add(cb.or(matchName, matchOrder, matchDevice, matchContent, matchCode));
            }

            return cb.and(predicates.toArray(new Predicate[0]));
        };

        return feedbackRepository.findAll(spec, pageable).map(this::mapToResponse);
    }

    @Transactional
    public CustomerFeedbackResponse replyFeedback(UUID id, ReplyCustomerFeedbackRequest request, String defaultReplier) {
        CustomerFeedback feedback = feedbackRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phản hồi: " + id));

        String newStatus = request.getStatus() != null ? request.getStatus() : "IN_PROGRESS";
        feedback.setStatus(newStatus);
        if ("RESOLVED".equalsIgnoreCase(newStatus)) {
            feedback.setStatusName("Đã giải quyết");
        } else if ("PENDING".equalsIgnoreCase(newStatus)) {
            feedback.setStatusName("Chờ tiếp nhận");
        } else {
            feedback.setStatusName("Đang xử lý");
        }

        feedback.setReply(request.getReply());
        feedback.setReplyAt(Instant.now());
        feedback.setRepliedBy(request.getRepliedBy() != null && !request.getRepliedBy().isBlank() ? request.getRepliedBy() : defaultReplier);

        feedback = feedbackRepository.save(feedback);
        return mapToResponse(feedback);
    }

    @Transactional
    public CustomerFeedbackResponse updateStatus(UUID id, String status) {
        CustomerFeedback feedback = feedbackRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phản hồi: " + id));

        feedback.setStatus(status);
        if ("RESOLVED".equalsIgnoreCase(status)) {
            feedback.setStatusName("Đã giải quyết");
        } else if ("PENDING".equalsIgnoreCase(status)) {
            feedback.setStatusName("Chờ tiếp nhận");
        } else {
            feedback.setStatusName("Đang xử lý");
        }

        feedback = feedbackRepository.save(feedback);
        return mapToResponse(feedback);
    }

    private CustomerFeedbackResponse mapToResponse(CustomerFeedback f) {
        List<String> tagsList = f.getTags() != null && !f.getTags().isBlank()
                ? Arrays.stream(f.getTags().split(",")).map(String::trim).filter(s -> !s.isEmpty()).collect(Collectors.toList())
                : Collections.emptyList();

        List<String> imagesList = f.getImages() != null && !f.getImages().isBlank()
                ? Arrays.stream(f.getImages().split(",")).map(String::trim).filter(s -> !s.isEmpty()).collect(Collectors.toList())
                : Collections.emptyList();

        return CustomerFeedbackResponse.builder()
                .id(f.getId())
                .orderCode(f.getOrderCode())
                .customerId(f.getCustomerId())
                .customerName(f.getCustomerName())
                .customerPhone(f.getCustomerPhone())
                .customerCode(f.getCustomerCode())
                .deviceModel(f.getDeviceModel())
                .rating(f.getRating())
                .type(f.getType())
                .typeName(f.getTypeName())
                .tags(tagsList)
                .content(f.getContent())
                .images(imagesList)
                .status(f.getStatus())
                .statusName(f.getStatusName())
                .reply(f.getReply())
                .replyAt(f.getReplyAt())
                .repliedBy(f.getRepliedBy())
                .isUrgent(f.isUrgent())
                .createdAt(f.getCreatedAt())
                .updatedAt(f.getUpdatedAt())
                .build();
    }
}
