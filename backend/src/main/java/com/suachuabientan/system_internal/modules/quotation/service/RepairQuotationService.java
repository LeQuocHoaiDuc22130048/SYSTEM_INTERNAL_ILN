package com.suachuabientan.system_internal.modules.quotation.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.customer.dto.PortalSupportConfigResponse;
import com.suachuabientan.system_internal.modules.customer.entity.Customer;
import com.suachuabientan.system_internal.modules.customer.entity.CustomerAccount;
import com.suachuabientan.system_internal.modules.customer.repository.CustomerAccountRepository;
import com.suachuabientan.system_internal.modules.customer.repository.CustomerRepository;
import com.suachuabientan.system_internal.modules.customer.service.PortalSupportConfigService;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import com.suachuabientan.system_internal.modules.quotation.dto.*;
import com.suachuabientan.system_internal.modules.quotation.entity.RepairPaymentProof;
import com.suachuabientan.system_internal.modules.quotation.entity.RepairQuotation;
import com.suachuabientan.system_internal.modules.quotation.entity.RepairQuotationItem;
import com.suachuabientan.system_internal.modules.quotation.entity.RepairQuotationLineItem;
import com.suachuabientan.system_internal.modules.quotation.enums.PaymentProofStatus;
import com.suachuabientan.system_internal.modules.quotation.enums.QuotationItemDecision;
import com.suachuabientan.system_internal.modules.quotation.enums.QuotationStatus;
import com.suachuabientan.system_internal.modules.quotation.repository.RepairPaymentProofRepository;
import com.suachuabientan.system_internal.modules.quotation.repository.RepairQuotationItemRepository;
import com.suachuabientan.system_internal.modules.quotation.repository.RepairQuotationRepository;
import com.suachuabientan.system_internal.modules.repair.entity.RepairOrder;
import com.suachuabientan.system_internal.modules.repair.entity.RepairTimeline;
import com.suachuabientan.system_internal.modules.repair.enums.RepairMediaType;
import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import com.suachuabientan.system_internal.modules.repair.repository.RepairOrderRepository;
import com.suachuabientan.system_internal.modules.repair.repository.RepairTimelineRepository;
import com.suachuabientan.system_internal.modules.repair.service.RepairMediaStorageService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class RepairQuotationService {

    private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("yyyyMMdd");
    private static final List<RepairStatus> QUOTABLE_ORDER_STATUSES = List.of(
            RepairStatus.PENDING,
            RepairStatus.WAITING_FOR_CHECK,
            RepairStatus.CHECKING,
            RepairStatus.CHECKED
    );
    private static final List<QuotationStatus> ACTIVE_QUOTATION_STATUSES = List.of(
            QuotationStatus.DRAFT,
            QuotationStatus.SENT
    );

    private final RepairQuotationRepository quotationRepository;
    private final RepairQuotationItemRepository quotationItemRepository;
    private final RepairPaymentProofRepository paymentProofRepository;
    private final RepairOrderRepository repairOrderRepository;
    private final RepairTimelineRepository repairTimelineRepository;
    private final CustomerRepository customerRepository;
    private final CustomerAccountRepository customerAccountRepository;
    private final PortalSupportConfigService portalSupportConfigService;
    private final NotificationService notificationService;
    private final RepairMediaStorageService repairMediaStorageService;
    private final ObjectMapper objectMapper;

    // ── Staff APIs ────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<PendingQuotationOrderResponse> getPendingOrdersForCustomer(UUID customerId) {
        if (customerId == null) {
            return List.of();
        }
        List<RepairOrder> candidateOrders = repairOrderRepository
                .findByCustomerIdAndStatusInAndIsDeletedFalseOrderByReceivedAtDesc(customerId, QUOTABLE_ORDER_STATUSES);
        if (candidateOrders.isEmpty()) {
            return List.of();
        }
        List<UUID> candidateIds = candidateOrders.stream().map(RepairOrder::getId).toList();
        Set<UUID> busyOrderIds = new HashSet<>(quotationItemRepository
                .findOrderIdsWithActiveQuotations(candidateIds, ACTIVE_QUOTATION_STATUSES));

        return candidateOrders.stream()
                .filter(order -> !busyOrderIds.contains(order.getId()))
                .map(order -> new PendingQuotationOrderResponse(
                        order.getId(),
                        order.getOrderCode(),
                        order.getDeviceName(),
                        order.getDeviceType(),
                        order.getSerialNumber(),
                        order.getStatus(),
                        order.getStatus() != null ? order.getStatus().getLabel() : "",
                        order.getReceivedAt(),
                        order.getDescription()
                ))
                .toList();
    }

    @Transactional
    public QuotationResponse createQuotation(CreateQuotationRequest request, UUID staffUserId) {
        if (request.items() == null || request.items().isEmpty()) {
            throw new BusinessException("Báo giá phải có ít nhất 1 thiết bị");
        }

        List<UUID> orderIds = request.items().stream()
                .map(CreateQuotationItemRequest::repairOrderId)
                .toList();
        if (new HashSet<>(orderIds).size() != orderIds.size()) {
            throw new BusinessException("Danh sách thiết bị trong báo giá bị trùng mã đơn");
        }

        List<RepairOrder> orders = new ArrayList<>();
        for (UUID orderId : orderIds) {
            RepairOrder order = repairOrderRepository.findByIdAndIsDeletedFalse(orderId)
                    .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn sửa chữa: " + orderId));
            if (order.getStatus() == RepairStatus.DELIVERED || order.getStatus() == RepairStatus.CANCELLED) {
                throw new BusinessException("Đơn " + order.getOrderCode() + " đã kết thúc, không thể tạo báo giá");
            }
            if (order.getCustomerId() == null) {
                throw new BusinessException("Đơn " + order.getOrderCode() + " chưa được gán hồ sơ khách hàng");
            }
            orders.add(order);
        }

        UUID resolvedCustomerId = request.customerId() != null ? request.customerId() : orders.get(0).getCustomerId();
        for (RepairOrder order : orders) {
            if (!resolvedCustomerId.equals(order.getCustomerId())) {
                throw new BusinessException("Tất cả đơn gộp trong cùng một báo giá phải thuộc cùng một khách hàng");
            }
        }

        List<UUID> busyOrderIds = quotationItemRepository.findOrderIdsWithActiveQuotations(orderIds, ACTIVE_QUOTATION_STATUSES);
        if (!busyOrderIds.isEmpty()) {
            throw new BusinessException("Một hoặc nhiều đơn đã nằm trong báo giá đang chờ duyệt");
        }

        Customer customer = customerRepository.findByIdAndIsDeletedFalse(resolvedCustomerId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy hồ sơ khách hàng: " + resolvedCustomerId));

        Map<UUID, RepairOrder> orderMap = orders.stream()
                .collect(Collectors.toMap(RepairOrder::getId, Function.identity()));

        boolean sendNow = request.sendImmediately() == null || Boolean.TRUE.equals(request.sendImmediately());
        Instant now = Instant.now();

        RepairQuotation quotation = RepairQuotation.builder()
                .quoteCode(generateQuoteCode())
                .customerId(customer.getId())
                .customerName(customer.getCustomerName())
                .customerPhone(customer.getPhone())
                .title(request.title() != null && !request.title().isBlank()
                        ? request.title().trim()
                        : (orders.size() == 1
                        ? "Báo giá sửa chữa " + orders.get(0).getDeviceName()
                        : "Báo giá sửa chữa tổng hợp (" + orders.size() + " thiết bị)"))
                .note(request.note() != null ? request.note().trim() : null)
                .status(sendNow ? QuotationStatus.SENT : QuotationStatus.DRAFT)
                .sentAt(sendNow ? now : null)
                .expiresAt(request.expiresAt())
                .build();

        BigDecimal totalEstimated = BigDecimal.ZERO;
        List<RepairQuotationItem> itemEntities = new ArrayList<>();

        for (int idx = 0; idx < request.items().size(); idx++) {
            CreateQuotationItemRequest itemReq = request.items().get(idx);
            RepairOrder order = orderMap.get(itemReq.repairOrderId());

            List<WarrantyOptionDto> warrantyOptions = (itemReq.warrantyOptions() != null && !itemReq.warrantyOptions().isEmpty())
                    ? itemReq.warrantyOptions()
                    : defaultWarrantyOptions();
            WarrantyOptionDto defaultWarranty = warrantyOptions.get(0);

            RepairQuotationItem item = RepairQuotationItem.builder()
                    .quotation(quotation)
                    .repairOrderId(order.getId())
                    .orderCode(order.getOrderCode())
                    .deviceName(order.getDeviceName())
                    .deviceType(order.getDeviceType())
                    .serialNumber(order.getSerialNumber())
                    .diagnosedErrorsJson(writeJson(itemReq.diagnosedErrors() != null ? itemReq.diagnosedErrors() : List.of()))
                    .warrantyOptionsJson(writeJson(warrantyOptions))
                    .selectedWarrantyCode(defaultWarranty.code())
                    .selectedWarrantyLabel(defaultWarranty.label())
                    .warrantyFee(defaultWarranty.fee())
                    .decision(QuotationItemDecision.PENDING)
                    .sortOrder(idx)
                    .build();

            BigDecimal baseCost = BigDecimal.ZERO;
            List<RepairQuotationLineItem> lineItems = new ArrayList<>();
            for (int lIdx = 0; lIdx < itemReq.lineItems().size(); lIdx++) {
                QuotationLineItemRequest lineReq = itemReq.lineItems().get(lIdx);
                BigDecimal lineAmount = lineReq.unitPrice().multiply(BigDecimal.valueOf(lineReq.quantity()));
                baseCost = baseCost.add(lineAmount);
                lineItems.add(RepairQuotationLineItem.builder()
                        .quotationItem(item)
                        .description(lineReq.description().trim())
                        .quantity(lineReq.quantity())
                        .unitPrice(lineReq.unitPrice())
                        .amount(lineAmount)
                        .sortOrder(lIdx)
                        .build());
            }
            item.setLineItems(lineItems);
            item.setBaseCost(baseCost);
            item.setFinalAmount(baseCost.add(defaultWarranty.fee()));

            totalEstimated = totalEstimated.add(baseCost);
            itemEntities.add(item);
        }

        quotation.setItems(itemEntities);
        quotation.setTotalEstimatedAmount(totalEstimated);
        quotation.setTotalApprovedAmount(BigDecimal.ZERO);

        RepairQuotation saved = quotationRepository.save(quotation);

        if (sendNow) {
            recordOrderTimelineForQuotation(saved, "Gửi báo giá cho khách hàng",
                    "Đã gửi báo giá " + saved.getQuoteCode() + " tới khách hàng", staffUserId);
            notifyCustomerAccounts(saved,
                    NotificationType.QUOTATION_SENT,
                    "Bạn có báo giá mới cần xác nhận",
                    "Báo giá " + saved.getQuoteCode() + " (" + saved.getItems().size() + " thiết bị) đang chờ bạn duyệt.");
        }

        return toResponse(saved);
    }

    @Transactional
    public QuotationResponse sendQuotation(UUID quotationId, UUID staffUserId) {
        RepairQuotation quotation = findQuotationById(quotationId);
        if (quotation.getStatus() != QuotationStatus.DRAFT) {
            throw new BusinessException("Chỉ báo giá ở trạng thái Nháp mới có thể gửi cho khách hàng");
        }
        quotation.setStatus(QuotationStatus.SENT);
        quotation.setSentAt(Instant.now());
        RepairQuotation saved = quotationRepository.save(quotation);

        recordOrderTimelineForQuotation(saved, "Gửi báo giá cho khách hàng",
                "Đã gửi báo giá " + saved.getQuoteCode() + " tới khách hàng", staffUserId);
        notifyCustomerAccounts(saved,
                NotificationType.QUOTATION_SENT,
                "Bạn có báo giá mới cần xác nhận",
                "Báo giá " + saved.getQuoteCode() + " (" + saved.getItems().size() + " thiết bị) đang chờ bạn duyệt.");

        return toResponse(saved);
    }

    @Transactional
    public QuotationResponse cancelQuotation(UUID quotationId, UUID staffUserId) {
        RepairQuotation quotation = findQuotationById(quotationId);
        if (quotation.getStatus() != QuotationStatus.DRAFT && quotation.getStatus() != QuotationStatus.SENT) {
            throw new BusinessException("Chỉ có thể hủy báo giá ở trạng thái Nháp hoặc Chờ khách duyệt");
        }
        quotation.setStatus(QuotationStatus.CANCELLED);
        RepairQuotation saved = quotationRepository.save(quotation);

        recordOrderTimelineForQuotation(saved, "Hủy báo giá",
                "Nhân viên đã hủy báo giá " + saved.getQuoteCode(), staffUserId);
        return toResponse(saved);
    }

    @Transactional(readOnly = true)
    public Page<QuotationResponse> searchQuotations(UUID customerId, QuotationStatus status, UUID repairOrderId, Pageable pageable) {
        return quotationRepository.searchQuotations(customerId, status, repairOrderId, pageable)
                .map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public QuotationResponse getQuotationById(UUID quotationId) {
        return toResponse(findQuotationById(quotationId));
    }

    @Transactional(readOnly = true)
    public List<QuotationResponse> getQuotationsByOrderId(UUID repairOrderId) {
        List<RepairQuotationItem> items = quotationItemRepository.findByRepairOrderIdWithQuotation(repairOrderId);
        return items.stream()
                .map(RepairQuotationItem::getQuotation)
                .distinct()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public PaymentProofResponse verifyPaymentProof(UUID proofId, UUID staffUserId, VerifyPaymentProofRequest request) {
        RepairPaymentProof proof = paymentProofRepository.findByIdAndIsDeletedFalse(proofId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy chứng từ thanh toán: " + proofId));
        if (proof.getStatus() != PaymentProofStatus.PENDING_VERIFY) {
            throw new BusinessException("Chứng từ này đã được đối soát trước đó");
        }
        RepairQuotation quotation = findQuotationById(proof.getQuotationId());

        if (request.approved()) {
            proof.setStatus(PaymentProofStatus.VERIFIED);
            proof.setRejectionReason(null);
        } else {
            if (request.rejectionReason() == null || request.rejectionReason().isBlank()) {
                throw new BusinessException("Vui lòng nhập lý do từ chối chứng từ");
            }
            proof.setStatus(PaymentProofStatus.REJECTED);
            proof.setRejectionReason(request.rejectionReason().trim());
        }
        proof.setVerifiedBy(staffUserId);
        proof.setVerifiedAt(Instant.now());
        RepairPaymentProof saved = paymentProofRepository.save(proof);

        notifyCustomerAccounts(quotation,
                NotificationType.PAYMENT_PROOF_VERIFIED,
                request.approved() ? "Đã xác nhận thanh toán" : "Chứng từ thanh toán cần kiểm tra lại",
                request.approved()
                        ? "Xưởng đã xác nhận thanh toán cho báo giá " + quotation.getQuoteCode() + "."
                        : "Chứng từ báo giá " + quotation.getQuoteCode() + " bị từ chối: " + saved.getRejectionReason());

        return toPaymentProofResponse(saved);
    }

    // ── Customer Portal APIs ──────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public Page<QuotationResponse> getMyQuotations(UUID customerUserId, QuotationStatus status, Pageable pageable) {
        CustomerAccount account = requireCustomerAccount(customerUserId);
        Page<RepairQuotation> page = status != null
                ? quotationRepository.findByCustomerIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
                account.getCustomerId(), status, pageable)
                : quotationRepository.findByCustomerIdAndIsDeletedFalseAndStatusNotOrderByCreatedAtDesc(
                account.getCustomerId(), QuotationStatus.DRAFT, pageable);
        return page.map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public QuotationResponse getMyQuotationDetail(UUID customerUserId, UUID quotationId) {
        CustomerAccount account = requireCustomerAccount(customerUserId);
        RepairQuotation quotation = quotationRepository.findByIdAndCustomerIdAndIsDeletedFalse(quotationId, account.getCustomerId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy báo giá: " + quotationId));
        if (quotation.getStatus() == QuotationStatus.DRAFT) {
            throw new ResourceNotFoundException("Báo giá chưa được gửi");
        }
        return toResponse(quotation);
    }

    @Transactional
    public QuotationResponse respondToQuotation(UUID quotationId, UUID customerUserId, RespondQuotationRequest request) {
        CustomerAccount account = requireCustomerAccount(customerUserId);
        RepairQuotation quotation = quotationRepository.findByIdAndCustomerIdAndIsDeletedFalse(quotationId, account.getCustomerId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy báo giá: " + quotationId));

        if (quotation.getStatus() != QuotationStatus.SENT) {
            throw new BusinessException("Báo giá này đã được xác nhận trước đó hoặc không còn ở trạng thái chờ duyệt");
        }
        if (quotation.getExpiresAt() != null && Instant.now().isAfter(quotation.getExpiresAt())) {
            quotation.setStatus(QuotationStatus.EXPIRED);
            quotationRepository.save(quotation);
            throw new BusinessException("Báo giá này đã hết hiệu lực, vui lòng liên hệ kỹ thuật viên để cấp lại");
        }

        Map<UUID, QuotationItemDecisionRequest> decisionMap = request.items().stream()
                .collect(Collectors.toMap(
                        QuotationItemDecisionRequest::quotationItemId,
                        Function.identity(),
                        (a, b) -> b
                ));

        Instant now = Instant.now();
        int approvedCount = 0;
        int rejectedCount = 0;
        BigDecimal totalApprovedAmount = BigDecimal.ZERO;

        for (RepairQuotationItem item : quotation.getItems()) {
            QuotationItemDecisionRequest decisionReq = decisionMap.get(item.getId());
            if (decisionReq == null || decisionReq.decision() == null || decisionReq.decision() == QuotationItemDecision.PENDING) {
                throw new BusinessException("Vui lòng chọn Đồng ý hoặc Từ chối cho thiết bị " + item.getDeviceName() + " (" + item.getOrderCode() + ")");
            }

            item.setDecision(decisionReq.decision());
            item.setDecidedAt(now);

            RepairOrder order = repairOrderRepository.findByIdAndIsDeletedFalse(item.getRepairOrderId())
                    .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn sửa chữa: " + item.getRepairOrderId()));

            if (decisionReq.decision() == QuotationItemDecision.APPROVED) {
                approvedCount++;
                List<WarrantyOptionDto> options = readWarrantyOptions(item.getWarrantyOptionsJson());
                WarrantyOptionDto selectedOption = resolveWarrantyOption(options, decisionReq.selectedWarrantyCode());

                item.setSelectedWarrantyCode(selectedOption.code());
                item.setSelectedWarrantyLabel(selectedOption.label());
                item.setWarrantyFee(selectedOption.fee());
                item.setFinalAmount(item.getBaseCost().add(selectedOption.fee()));
                item.setRejectReason(null);

                totalApprovedAmount = totalApprovedAmount.add(item.getFinalAmount());

                if (order.getStatus() != RepairStatus.COMPLETED && order.getStatus() != RepairStatus.DELIVERED) {
                    order.setStatus(RepairStatus.IN_PROGRESS);
                    if (order.getStartedAt() == null) {
                        order.setStartedAt(now);
                    }
                    order.setUnderWarranty(true);
                    repairOrderRepository.save(order);
                }
                addTimeline(order.getId(),
                        "Khách hàng duyệt báo giá",
                        String.format("Khách duyệt sửa theo báo giá %s (%s). Tổng: %,.0f đ",
                                quotation.getQuoteCode(), selectedOption.label(), item.getFinalAmount()),
                        customerUserId);
            } else {
                rejectedCount++;
                item.setWarrantyFee(BigDecimal.ZERO);
                item.setFinalAmount(BigDecimal.ZERO);
                item.setRejectReason(decisionReq.rejectReason() != null && !decisionReq.rejectReason().isBlank()
                        ? decisionReq.rejectReason().trim() : null);

                if (order.getStatus() != RepairStatus.COMPLETED && order.getStatus() != RepairStatus.DELIVERED) {
                    order.setStatus(RepairStatus.CANCELLED);
                    repairOrderRepository.save(order);
                }
                String reasonSuffix = item.getRejectReason() != null ? " — Lý do: " + item.getRejectReason() : "";
                addTimeline(order.getId(),
                        "Khách hàng từ chối báo giá",
                        "Khách từ chối sửa theo báo giá " + quotation.getQuoteCode() + reasonSuffix,
                        customerUserId);
            }
        }

        quotation.setTotalApprovedAmount(totalApprovedAmount);
        quotation.setRespondedAt(now);
        if (approvedCount == quotation.getItems().size()) {
            quotation.setStatus(QuotationStatus.APPROVED);
        } else if (rejectedCount == quotation.getItems().size()) {
            quotation.setStatus(QuotationStatus.REJECTED);
        } else {
            quotation.setStatus(QuotationStatus.PARTIAL_APPROVED);
        }

        RepairQuotation saved = quotationRepository.save(quotation);

        notifyStaffForQuotationEvent(saved,
                NotificationType.QUOTATION_RESPONDED,
                "Khách hàng đã phản hồi báo giá " + saved.getQuoteCode(),
                String.format("%s: %d/%d thiết bị đồng ý sửa (Tổng: %,.0f đ).",
                        saved.getCustomerName(), approvedCount, saved.getItems().size(), totalApprovedAmount));

        return toResponse(saved);
    }

    @Transactional
    public PaymentProofResponse submitPaymentProof(
            UUID quotationId,
            UUID customerUserId,
            MultipartFile file,
            BigDecimal amount,
            String note) {
        CustomerAccount account = requireCustomerAccount(customerUserId);
        RepairQuotation quotation = quotationRepository.findByIdAndCustomerIdAndIsDeletedFalse(quotationId, account.getCustomerId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy báo giá: " + quotationId));

        if (quotation.getStatus() != QuotationStatus.APPROVED && quotation.getStatus() != QuotationStatus.PARTIAL_APPROVED) {
            throw new BusinessException("Chỉ có thể tải chứng từ thanh toán sau khi đã duyệt ít nhất 1 thiết bị trong báo giá");
        }
        if (file == null || file.isEmpty()) {
            throw new BusinessException("Vui lòng chọn ảnh hoặc file PDF chứng từ thanh toán");
        }

        String originalName = file.getOriginalFilename() != null ? file.getOriginalFilename().toLowerCase(Locale.ROOT) : "";
        RepairMediaType mediaType = originalName.endsWith(".pdf") ? RepairMediaType.DOCUMENT : RepairMediaType.IMAGE;
        RepairMediaStorageService.StoredMedia stored = repairMediaStorageService.store(file, mediaType);

        BigDecimal resolvedAmount = (amount != null && amount.compareTo(BigDecimal.ZERO) > 0)
                ? amount
                : quotation.getTotalApprovedAmount();

        RepairPaymentProof proof = RepairPaymentProof.builder()
                .quotationId(quotation.getId())
                .amount(resolvedAmount)
                .transferContent(quotation.getQuoteCode())
                .proofFileUrl(stored.publicUrl())
                .proofFileName(stored.originalFileName())
                .note(note != null && !note.isBlank() ? note.trim() : null)
                .status(PaymentProofStatus.PENDING_VERIFY)
                .build();

        RepairPaymentProof saved = paymentProofRepository.save(proof);

        notifyStaffForQuotationEvent(quotation,
                NotificationType.PAYMENT_PROOF_SUBMITTED,
                "Khách đã gửi chứng từ thanh toán",
                String.format("%s đã tải lên chứng từ cho báo giá %s (%,.0f đ).",
                        quotation.getCustomerName(), quotation.getQuoteCode(), resolvedAmount));

        return toPaymentProofResponse(saved);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private CustomerAccount requireCustomerAccount(UUID userId) {
        return customerAccountRepository.findByUserIdAndActiveTrueAndIsDeletedFalse(userId)
                .orElseThrow(() -> new BusinessException("Tài khoản chưa được liên kết với hồ sơ khách hàng hoặc đã bị khóa", 403));
    }

    private RepairQuotation findQuotationById(UUID quotationId) {
        return quotationRepository.findByIdAndIsDeletedFalse(quotationId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy báo giá: " + quotationId));
    }

    private synchronized String generateQuoteCode() {
        String today = LocalDate.now().format(DATE_FORMAT);
        String prefix = "QT-" + today + "-";
        int seq = 1;
        String candidate = prefix + String.format("%03d", seq);
        while (quotationRepository.existsByQuoteCode(candidate)) {
            seq++;
            candidate = prefix + String.format("%03d", seq);
        }
        return candidate;
    }

    private List<WarrantyOptionDto> defaultWarrantyOptions() {
        return List.of(
                new WarrantyOptionDto("STANDARD_6M", "Bảo hành 6 tháng", "Gói tiêu chuẩn", 6, BigDecimal.ZERO),
                new WarrantyOptionDto("EXTENDED_12M", "Bảo hành 1 năm", "Bảo vệ toàn diện linh kiện", 12, new BigDecimal("500000"))
        );
    }

    private WarrantyOptionDto resolveWarrantyOption(List<WarrantyOptionDto> options, String code) {
        if (options.isEmpty()) {
            options = defaultWarrantyOptions();
        }
        if (code == null || code.isBlank()) {
            return options.get(0);
        }
        return options.stream()
                .filter(opt -> code.equalsIgnoreCase(opt.code()))
                .findFirst()
                .orElseThrow(() -> new BusinessException("Gói bảo hành không hợp lệ: " + code));
    }

    private void recordOrderTimelineForQuotation(RepairQuotation quotation, String action, String note, UUID actorId) {
        for (RepairQuotationItem item : quotation.getItems()) {
            addTimeline(item.getRepairOrderId(), action, note, actorId);
        }
    }

    private void addTimeline(UUID orderId, String action, String note, UUID performedBy) {
        repairTimelineRepository.save(RepairTimeline.builder()
                .orderId(orderId)
                .action(action)
                .note(note)
                .performedBy(performedBy)
                .createdAt(Instant.now())
                .createdBy(performedBy)
                .build());
    }

    private void notifyCustomerAccounts(RepairQuotation quotation, NotificationType type, String title, String body) {
        try {
            List<CustomerAccount> accounts = customerAccountRepository
                    .findByCustomerIdAndIsDeletedFalseOrderByCreatedAtDesc(quotation.getCustomerId());
            for (CustomerAccount account : accounts) {
                if (account.isActive()) {
                    notificationService.sendToUser(
                            account.getUserId(),
                            type,
                            title,
                            body,
                            "REPAIR_QUOTATION",
                            quotation.getId().toString(),
                            true
                    );
                }
            }
        } catch (Exception ex) {
            log.warn("Không thể gửi thông báo tới khách hàng cho báo giá {}: {}", quotation.getQuoteCode(), ex.getMessage());
        }
    }

    private void notifyStaffForQuotationEvent(RepairQuotation quotation, NotificationType type, String title, String body) {
        try {
            Set<UUID> recipients = new LinkedHashSet<>();
            if (quotation.getCreatedBy() != null) {
                recipients.add(quotation.getCreatedBy());
            }
            for (RepairQuotationItem item : quotation.getItems()) {
                repairOrderRepository.findByIdAndIsDeletedFalse(item.getRepairOrderId()).ifPresent(order -> {
                    if (order.getReceivedBy() != null) recipients.add(order.getReceivedBy());
                    if (order.getAssignedTo() != null) recipients.add(order.getAssignedTo());
                });
            }
            for (UUID userId : recipients) {
                notificationService.sendToUser(
                        userId,
                        type,
                        title,
                        body,
                        "REPAIR_QUOTATION",
                        quotation.getId().toString(),
                        true
                );
            }
        } catch (Exception ex) {
            log.warn("Không thể gửi thông báo cho nhân viên về báo giá {}: {}", quotation.getQuoteCode(), ex.getMessage());
        }
    }

    private QuotationResponse toResponse(RepairQuotation quotation) {
        List<QuotationItemResponse> itemResponses = quotation.getItems().stream()
                .map(this::toItemResponse)
                .toList();

        int approvedCount = (int) itemResponses.stream().filter(i -> i.decision() == QuotationItemDecision.APPROVED).count();
        int rejectedCount = (int) itemResponses.stream().filter(i -> i.decision() == QuotationItemDecision.REJECTED).count();
        int pendingCount = (int) itemResponses.stream().filter(i -> i.decision() == QuotationItemDecision.PENDING).count();

        BigDecimal qrAmount = quotation.getTotalApprovedAmount() != null && quotation.getTotalApprovedAmount().compareTo(BigDecimal.ZERO) > 0
                ? quotation.getTotalApprovedAmount()
                : quotation.getTotalEstimatedAmount();

        PortalSupportConfigResponse supportConfig = portalSupportConfigService.getSupportConfig();
        String vietQrPayload = VietQrPayloadBuilder.build(
                supportConfig.getBankBin(),
                supportConfig.getBankAccountNumber(),
                qrAmount,
                quotation.getQuoteCode()
        );
        QuotationBankInfoResponse bankInfo = new QuotationBankInfoResponse(
                supportConfig.getBankName(),
                supportConfig.getBankBin(),
                supportConfig.getBankAccountNumber(),
                supportConfig.getBankAccountHolder(),
                quotation.getQuoteCode(),
                qrAmount,
                vietQrPayload
        );

        List<PaymentProofResponse> proofs = paymentProofRepository
                .findByQuotationIdAndIsDeletedFalseOrderByCreatedAtDesc(quotation.getId())
                .stream()
                .map(this::toPaymentProofResponse)
                .toList();

        return new QuotationResponse(
                quotation.getId(),
                quotation.getQuoteCode(),
                quotation.getCustomerId(),
                quotation.getCustomerName(),
                quotation.getCustomerPhone(),
                quotation.getTitle(),
                quotation.getNote(),
                quotation.getStatus(),
                quotation.getStatus() != null ? quotation.getStatus().getLabel() : "",
                quotation.getTotalEstimatedAmount(),
                quotation.getTotalApprovedAmount(),
                quotation.getSentAt(),
                quotation.getRespondedAt(),
                quotation.getExpiresAt(),
                quotation.getCreatedAt(),
                itemResponses.size(),
                approvedCount,
                rejectedCount,
                pendingCount,
                bankInfo,
                itemResponses,
                proofs
        );
    }

    private QuotationItemResponse toItemResponse(RepairQuotationItem item) {
        List<QuotationLineItemResponse> lines = item.getLineItems().stream()
                .map(l -> new QuotationLineItemResponse(
                        l.getId(),
                        l.getDescription(),
                        l.getQuantity(),
                        l.getUnitPrice(),
                        l.getAmount(),
                        l.getSortOrder()
                ))
                .toList();

        return new QuotationItemResponse(
                item.getId(),
                item.getRepairOrderId(),
                item.getOrderCode(),
                item.getDeviceName(),
                item.getDeviceType(),
                item.getSerialNumber(),
                readDiagnosedErrors(item.getDiagnosedErrorsJson()),
                lines,
                item.getBaseCost(),
                readWarrantyOptions(item.getWarrantyOptionsJson()),
                item.getSelectedWarrantyCode(),
                item.getSelectedWarrantyLabel(),
                item.getWarrantyFee(),
                item.getFinalAmount(),
                item.getDecision(),
                item.getDecision() != null ? item.getDecision().getLabel() : "",
                item.getRejectReason(),
                item.getDecidedAt()
        );
    }

    private PaymentProofResponse toPaymentProofResponse(RepairPaymentProof proof) {
        return new PaymentProofResponse(
                proof.getId(),
                proof.getQuotationId(),
                proof.getAmount(),
                proof.getTransferContent(),
                proof.getProofFileUrl(),
                proof.getProofFileName(),
                proof.getNote(),
                proof.getStatus(),
                proof.getStatus() != null ? proof.getStatus().getLabel() : "",
                proof.getVerifiedBy(),
                proof.getVerifiedAt(),
                proof.getRejectionReason(),
                proof.getCreatedAt()
        );
    }

    private String writeJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (Exception ex) {
            return "[]";
        }
    }

    private List<DiagnosedErrorDto> readDiagnosedErrors(String json) {
        if (json == null || json.isBlank()) return List.of();
        try {
            return objectMapper.readValue(json, new TypeReference<>() {});
        } catch (Exception ex) {
            return List.of();
        }
    }

    private List<WarrantyOptionDto> readWarrantyOptions(String json) {
        if (json == null || json.isBlank()) return defaultWarrantyOptions();
        try {
            List<WarrantyOptionDto> list = objectMapper.readValue(json, new TypeReference<>() {});
            return list.isEmpty() ? defaultWarrantyOptions() : list;
        } catch (Exception ex) {
            return defaultWarrantyOptions();
        }
    }
}
