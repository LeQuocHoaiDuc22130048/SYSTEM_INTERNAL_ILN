package com.suachuabientan.system_internal.modules.customer.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerOrderConfirmRequest;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerOrderConfirmationResponse;
import com.suachuabientan.system_internal.modules.customer.dto.OrderQuoteLineItemDto;
import com.suachuabientan.system_internal.modules.customer.entity.CustomerAccount;
import com.suachuabientan.system_internal.modules.customer.entity.RepairOrderConfirmation;
import com.suachuabientan.system_internal.modules.customer.repository.CustomerAccountRepository;
import com.suachuabientan.system_internal.modules.customer.repository.RepairOrderConfirmationRepository;
import com.suachuabientan.system_internal.modules.repair.entity.RepairCustomerUpdate;
import com.suachuabientan.system_internal.modules.repair.entity.RepairDevice;
import com.suachuabientan.system_internal.modules.repair.entity.RepairOrder;
import com.suachuabientan.system_internal.modules.repair.enums.RepairMediaType;
import com.suachuabientan.system_internal.modules.repair.repository.RepairCustomerUpdateRepository;
import com.suachuabientan.system_internal.modules.repair.repository.RepairDeviceRepository;
import com.suachuabientan.system_internal.modules.repair.repository.RepairOrderRepository;
import com.suachuabientan.system_internal.modules.repair.service.RepairMediaStorageService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.text.NumberFormat;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class CustomerOrderConfirmationService {

    public static final String STATUS_PENDING_CUSTOMER = "PENDING_CUSTOMER";
    public static final String STATUS_APPROVED = "APPROVED";
    public static final String STATUS_PAYMENT_SUBMITTED = "PAYMENT_SUBMITTED";
    public static final String STATUS_REJECTED = "REJECTED";

    public static final String BANK_NAME = "MB Bank (Quân Đội)";
    public static final String BANK_CODE = "MB";
    public static final String ACCOUNT_NUMBER = "9964266771";
    public static final String ACCOUNT_HOLDER = "CONG TY TNHH KY THUAT CONG NGHE";
    public static final long EXTENDED_WARRANTY_FEE = 500_000L;

    private final CustomerAccountRepository customerAccountRepository;
    private final RepairOrderRepository repairOrderRepository;
    private final RepairDeviceRepository repairDeviceRepository;
    private final RepairOrderConfirmationRepository confirmationRepository;
    private final RepairCustomerUpdateRepository repairCustomerUpdateRepository;
    private final RepairMediaStorageService repairMediaStorageService;
    private final ObjectMapper objectMapper;

    @Transactional(readOnly = true)
    public CustomerOrderConfirmationResponse getConfirmation(UUID userId, UUID orderId) {
        RepairOrder order = requireCustomerOrder(userId, orderId);
        RepairOrderConfirmation entity = confirmationRepository.findByOrderIdAndIsDeletedFalse(orderId)
                .orElseGet(() -> RepairOrderConfirmation.builder()
                        .orderId(orderId)
                        .confirmationStatus(STATUS_PENDING_CUSTOMER)
                        .warrantyMonths(6)
                        .warrantyExtraFee(0L)
                        .baseAmount(0L)
                        .totalAmount(0L)
                        .build());
        return toResponse(order, entity);
    }

    @Transactional
    public CustomerOrderConfirmationResponse confirmQuote(
            UUID userId,
            UUID orderId,
            CustomerOrderConfirmRequest request) {
        RepairOrder order = requireCustomerOrder(userId, orderId);
        String action = request.action() == null ? "" : request.action().trim().toUpperCase(Locale.ROOT);
        if (!"APPROVE".equals(action) && !"REJECT".equals(action)) {
            throw new BusinessException("Hành động xác nhận không hợp lệ (chỉ hỗ trợ APPROVE hoặc REJECT)", 400);
        }

        RepairOrderConfirmation entity = getOrCreateEntity(orderId);

        if ("APPROVE".equals(action)) {
            int warrantyMonths = resolveWarrantyMonths(request.warrantyMonths(), entity.getWarrantyMonths());
            long extraFee = warrantyMonths == 12 ? EXTENDED_WARRANTY_FEE : 0L;
            long baseAmount = entity.getBaseAmount() != null ? entity.getBaseAmount() : 0L;

            entity.setWarrantyMonths(warrantyMonths);
            entity.setWarrantyExtraFee(extraFee);
            entity.setTotalAmount(baseAmount + extraFee);
            entity.setConfirmationStatus(STATUS_APPROVED);
            entity.setRejectionReason(null);
            entity.setApprovedAt(Instant.now());
            entity.setConfirmedByUserId(userId);

            RepairOrderConfirmation saved = confirmationRepository.save(entity);
            publishCustomerUpdate(
                    order,
                    userId,
                    "Khách hàng đã duyệt báo giá",
                    String.format(
                            "Khách hàng đã duyệt phương án sửa chữa (Gói bảo hành %s, tổng %s đ).",
                            warrantyMonths == 12 ? "1 năm" : "6 tháng",
                            formatVnd(saved.getTotalAmount())
                    )
            );
            return toResponse(order, saved);
        }

        String reason = request.rejectionReason() != null && !request.rejectionReason().isBlank()
                ? request.rejectionReason().strip()
                : "Khách hàng từ chối báo giá sửa chữa";
        entity.setConfirmationStatus(STATUS_REJECTED);
        entity.setRejectionReason(reason);
        entity.setRejectedAt(Instant.now());
        entity.setConfirmedByUserId(userId);

        RepairOrderConfirmation saved = confirmationRepository.save(entity);
        publishCustomerUpdate(
                order,
                userId,
                "Khách hàng từ chối báo giá",
                reason
        );
        return toResponse(order, saved);
    }

    @Transactional
    public CustomerOrderConfirmationResponse uploadPaymentProof(
            UUID userId,
            UUID orderId,
            MultipartFile file,
            Integer warrantyMonths,
            String transferReference) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException("Vui lòng chọn ảnh chứng từ thanh toán", 400);
        }

        RepairOrder order = requireCustomerOrder(userId, orderId);
        RepairOrderConfirmation entity = getOrCreateEntity(orderId);

        int resolvedWarranty = resolveWarrantyMonths(warrantyMonths, entity.getWarrantyMonths());
        long extraFee = resolvedWarranty == 12 ? EXTENDED_WARRANTY_FEE : 0L;
        long baseAmount = entity.getBaseAmount() != null ? entity.getBaseAmount() : 0L;

        RepairMediaStorageService.StoredMedia stored = repairMediaStorageService.store(file, RepairMediaType.IMAGE);

        Instant now = Instant.now();
        entity.setWarrantyMonths(resolvedWarranty);
        entity.setWarrantyExtraFee(extraFee);
        entity.setTotalAmount(baseAmount + extraFee);
        entity.setConfirmationStatus(STATUS_PAYMENT_SUBMITTED);
        entity.setPaymentProofUrl(stored.publicUrl());
        entity.setPaymentProofFileName(
                file.getOriginalFilename() != null && !file.getOriginalFilename().isBlank()
                        ? file.getOriginalFilename().strip()
                        : "payment-proof.jpg"
        );
        if (transferReference != null && !transferReference.isBlank()) {
            entity.setTransferReference(transferReference.strip());
        }
        if (entity.getApprovedAt() == null) {
            entity.setApprovedAt(now);
        }
        entity.setPaymentSubmittedAt(now);
        entity.setConfirmedByUserId(userId);

        RepairOrderConfirmation saved = confirmationRepository.save(entity);
        publishCustomerUpdate(
                order,
                userId,
                "Khách hàng đã gửi chứng từ thanh toán",
                String.format(
                        "Đã tải lên chứng từ %s (%s đ, gói bảo hành %s).",
                        saved.getPaymentProofFileName(),
                        formatVnd(saved.getTotalAmount()),
                        resolvedWarranty == 12 ? "1 năm" : "6 tháng"
                )
        );
        return toResponse(order, saved);
    }

    private RepairOrder requireCustomerOrder(UUID userId, UUID orderId) {
        CustomerAccount account = customerAccountRepository.findByUserIdAndActiveTrueAndIsDeletedFalse(userId)
                .orElseThrow(() -> new BusinessException("Tài khoản chưa được liên kết với hồ sơ khách hàng nào hoặc đã bị khóa", 403));

        RepairOrder order = repairOrderRepository.findByIdAndIsDeletedFalse(orderId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn hàng: " + orderId));

        if (order.getCustomerId() == null || !order.getCustomerId().equals(account.getCustomerId())) {
            throw new ResourceNotFoundException("Không tìm thấy đơn hàng: " + orderId);
        }
        return order;
    }

    private RepairOrderConfirmation getOrCreateEntity(UUID orderId) {
        return confirmationRepository.findByOrderIdAndIsDeletedFalse(orderId)
                .orElseGet(() -> RepairOrderConfirmation.builder()
                        .orderId(orderId)
                        .confirmationStatus(STATUS_PENDING_CUSTOMER)
                        .warrantyMonths(6)
                        .warrantyExtraFee(0L)
                        .baseAmount(0L)
                        .totalAmount(0L)
                        .build());
    }

    private int resolveWarrantyMonths(Integer requested, Integer existing) {
        int months = requested != null ? requested : (existing != null ? existing : 6);
        if (months != 6 && months != 12) {
            throw new BusinessException("Gói bảo hành không hợp lệ (chỉ hỗ trợ 6 hoặc 12 tháng)", 400);
        }
        return months;
    }

    private void publishCustomerUpdate(RepairOrder order, UUID userId, String title, String message) {
        if (repairCustomerUpdateRepository == null) {
            return;
        }
        RepairCustomerUpdate update = RepairCustomerUpdate.builder()
                .orderId(order.getId())
                .title(title)
                .message(message)
                .statusAtTime(order.getStatus() != null ? order.getStatus().name() : null)
                .publishedBy(userId)
                .publishedAt(Instant.now())
                .build();
        repairCustomerUpdateRepository.save(update);
    }

    private CustomerOrderConfirmationResponse toResponse(RepairOrder order, RepairOrderConfirmation entity) {
        int warrantyMonths = entity.getWarrantyMonths() != null ? entity.getWarrantyMonths() : 6;
        long extraFee = warrantyMonths == 12 ? EXTENDED_WARRANTY_FEE : 0L;
        long baseAmount = entity.getBaseAmount() != null ? entity.getBaseAmount() : 0L;
        long totalAmount = entity.getTotalAmount() != null && entity.getTotalAmount() > 0
                ? entity.getTotalAmount()
                : baseAmount + extraFee;

        List<String> diagnosisTags = parseDiagnosisTags(entity.getDiagnosisTagsJson(), order);
        List<OrderQuoteLineItemDto> quoteItems = parseQuoteItems(entity.getQuoteItemsJson());

        String transferContent = buildTransferContent(order);

        return new CustomerOrderConfirmationResponse(
                order.getId(),
                entity.getConfirmationStatus() != null ? entity.getConfirmationStatus() : STATUS_PENDING_CUSTOMER,
                warrantyMonths,
                extraFee,
                baseAmount,
                totalAmount,
                diagnosisTags,
                quoteItems,
                BANK_NAME,
                BANK_CODE,
                ACCOUNT_NUMBER,
                ACCOUNT_HOLDER,
                transferContent,
                entity.getPaymentProofUrl(),
                entity.getPaymentProofFileName(),
                entity.getRejectionReason(),
                entity.getApprovedAt(),
                entity.getRejectedAt(),
                entity.getPaymentSubmittedAt()
        );
    }

    private String buildTransferContent(RepairOrder order) {
        String code = order.getOrderCode() != null ? order.getOrderCode().strip() : "";
        String serial = order.getSerialNumber() != null ? order.getSerialNumber().strip() : "";
        if (serial.isEmpty() && repairDeviceRepository != null) {
            List<RepairDevice> devices = repairDeviceRepository.findByOrderIdOrderByCreatedAtAsc(order.getId());
            if (devices != null && !devices.isEmpty() && devices.get(0).getSerialNumber() != null) {
                serial = devices.get(0).getSerialNumber().strip();
            }
        }
        if (code.isEmpty()) {
            return serial;
        }
        return serial.isEmpty() ? code : code + " - " + serial;
    }

    private List<String> parseDiagnosisTags(String json, RepairOrder order) {
        if (json != null && !json.isBlank() && objectMapper != null) {
            try {
                List<String> parsed = objectMapper.readValue(json, new TypeReference<>() {});
                if (parsed != null && !parsed.isEmpty()) {
                    return parsed;
                }
            } catch (Exception e) {
                log.warn("Không thể đọc diagnosis_tags_json cho đơn {}: {}", order.getId(), e.getMessage());
            }
        }
        List<String> fallback = new ArrayList<>();
        if (order.getDescription() != null && !order.getDescription().isBlank()) {
            for (String part : order.getDescription().split("[,;\\n]+")) {
                String trimmed = part.strip();
                if (!trimmed.isEmpty()) {
                    fallback.add(trimmed);
                }
            }
        }
        return fallback;
    }

    private List<OrderQuoteLineItemDto> parseQuoteItems(String json) {
        if (json == null || json.isBlank() || objectMapper == null) {
            return List.of();
        }
        try {
            List<OrderQuoteLineItemDto> parsed = objectMapper.readValue(json, new TypeReference<>() {});
            return parsed != null ? parsed : List.of();
        } catch (Exception e) {
            log.warn("Không thể đọc quote_items_json: {}", e.getMessage());
            return List.of();
        }
    }

    private String formatVnd(long amount) {
        NumberFormat format = NumberFormat.getInstance(Locale.forLanguageTag("vi-VN"));
        return format.format(amount);
    }
}

