package com.suachuabientan.system_internal.modules.repair.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.common.util.OrderCodeGenerator;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.repair.dto.request.AssignRequest;
import com.suachuabientan.system_internal.modules.repair.dto.request.CreateRepairOrderRequest;
import com.suachuabientan.system_internal.modules.repair.dto.request.ReorderRequest;
import com.suachuabientan.system_internal.modules.repair.dto.request.UpdateStatusRequest;
import com.suachuabientan.system_internal.modules.repair.dto.response.RepairOrderResponse;
import com.suachuabientan.system_internal.modules.repair.dto.response.RepairTimelineResponse;
import com.suachuabientan.system_internal.modules.repair.entity.RepairImage;
import com.suachuabientan.system_internal.modules.repair.entity.RepairOrder;
import com.suachuabientan.system_internal.modules.repair.entity.RepairTimeline;
import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import com.suachuabientan.system_internal.modules.repository.RepairImageRepository;
import com.suachuabientan.system_internal.modules.repository.RepairOrderRepository;
import com.suachuabientan.system_internal.modules.repository.RepairTimelineRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class RepairService {
    private final RepairOrderRepository repairOrderRepository;
    private final RepairImageRepository repairImageRepository;
    private final RepairTimelineRepository repairTimelineRepository;
    private final UserRepository userRepository;
    private final OrderCodeGenerator orderCodeGenerator;

    // ── Tạo đơn ──────────────────────────────────────────────

    @Transactional
    public RepairOrderResponse create(CreateRepairOrderRequest request, UUID receivedByUserId) {
        String orderCode = orderCodeGenerator.generate();

        RepairOrder order = RepairOrder.builder()
                .orderCode(orderCode)
                .deviceName(request.deviceName())
                .deviceType(request.deviceType())
                .customerName(request.customerName())
                .customerPhone(request.customerPhone())
                .description(request.description())
                .status(RepairStatus.PENDING)
                .priority(100)
                .receivedBy(receivedByUserId)
                .receivedAt(Instant.now())
                .build();

        RepairOrder saved = repairOrderRepository.save(order);

        // Ghi timeline
        addTimeline(saved.getId(), "Tiếp nhận đơn",
                STR."Đơn \{orderCode} được tạo bởi \{getUserName(receivedByUserId)}",
                receivedByUserId);

        log.info("Tạo đơn sửa chữa: orderCode={}, by={}", orderCode, receivedByUserId);
        return toResponse(saved);
    }

    // ── Danh sách & tìm kiếm ─────────────────────────────────

    @Transactional(readOnly = true)
    public Page<RepairOrderResponse> getAll(
            String keyword, RepairStatus status, UUID assignedTo, Pageable pageable) {
        String statusStr = status != null ? status.name() : null;
        String assignedToStr = assignedTo != null ? assignedTo.toString() : null;
        return repairOrderRepository
                .searchOrders(keyword, statusStr, assignedToStr, pageable)
                .map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public RepairOrderResponse getById(UUID id) {
        return toResponse(findOrderById(id));
    }

    // ── Phân công kỹ thuật viên ───────────────────────────────

    @Transactional
    public RepairOrderResponse assign(UUID orderId, AssignRequest request, UUID managerId) {
        RepairOrder order = findOrderById(orderId);

        // Kiểm tra kỹ thuật viên tồn tại
        UserEntity technician = userRepository.findByIdAndIsDeletedFalse(request.technicianId())
                .orElseThrow(() -> new ResourceNotFoundException(
                        STR."Không tìm thấy kỹ thuật viên: \{request.technicianId()}"));

        UUID previousAssignee = order.getAssignedTo();
        order.setAssignedTo(request.technicianId());
        repairOrderRepository.save(order);

        String note = previousAssignee == null
                ? STR."Phân công cho \{technician.getFullName()}"
                : STR."Thay đổi phân công sang \{technician.getFullName()}";
        if (request.note() != null) note += STR." — \{request.note()}";

        addTimeline(orderId, "Phân công kỹ thuật viên", note, managerId);
        log.info("Phân công đơn: orderId={}, technician={}, by={}", orderId, request.technicianId(), managerId);

        return toResponse(repairOrderRepository.save(order));
    }

    // ── Cập nhật trạng thái ───────────────────────────────────

    @Transactional
    public RepairOrderResponse updateStatus(UUID orderId, UpdateStatusRequest request, UUID userId) {
        RepairOrder order = findOrderById(orderId);

        // Validate transition hợp lệ
        if (!order.canTransitionTo(request.status())) {
            throw new BusinessException(
                    STR."Không thể chuyển từ \{order.getStatus().name()} sang \{request.status().name()}");
        }

        // Kiểm tra quyền: chỉ người được assign mới có thể cập nhật IN_PROGRESS/COMPLETED
        if ((request.status() == RepairStatus.IN_PROGRESS
                || request.status() == RepairStatus.COMPLETED)
                && !userId.equals(order.getAssignedTo())) {
            throw new BusinessException("Chỉ kỹ thuật viên được phân công mới có thể cập nhật trạng thái này");
        }

        RepairStatus oldStatus = order.getStatus();
        order.setStatus(request.status());

        // Cập nhật mốc thời gian tương ứng
        switch (request.status()) {
            case IN_PROGRESS -> order.setStartedAt(Instant.now());
            case COMPLETED -> order.setCompletedAt(Instant.now());
            case DELIVERED -> order.setDeliveredAt(Instant.now());
            default -> {
            }
        }

        repairOrderRepository.save(order);

        String action = getStatusAction(request.status());
        addTimeline(orderId, action, request.note(), userId);
        log.info("Cập nhật trạng thái: orderId={}, {} → {}, by={}",
                orderId, oldStatus, request.status(), userId);

        return toResponse(order);
    }

    // ── Sắp xếp ưu tiên (kéo thả) ────────────────────────────

    @Transactional
    public void reorder(ReorderRequest request, UUID managerId) {
        request.items().forEach(item ->
                repairOrderRepository.updatePriority(item.orderId(), item.priority()));

        log.info("Cập nhật priority {} đơn bởi managerId={}", request.items().size(), managerId);
        addTimeline(
                request.items().get(0).orderId(),
                "Thay đổi ưu tiên",
                STR."Manager sắp xếp lại thứ tự \{request.items().size()} đơn",
                managerId);
    }

    // ── Timeline ──────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<RepairTimelineResponse> getTimeline(UUID orderId) {
        findOrderById(orderId); // Validate tồn tại
        return repairTimelineRepository.findByOrderIdOrderByCreatedAtDesc(orderId)
                .stream().map(this::toTimelineResponse).toList();
    }

    // ── Ảnh đính kèm ─────────────────────────────────────────

    @Transactional
    public RepairOrderResponse.ImageInfo addImage(
            UUID orderId, String imageUrl, String caption, UUID uploadedBy) {
        findOrderById(orderId); // Validate tồn tại

        RepairImage image = RepairImage.builder()
                .orderId(orderId)
                .imageUrl(imageUrl)
                .caption(caption)
                .uploadedBy(uploadedBy)
                .uploadedAt(Instant.now())
                .build();

        RepairImage saved = repairImageRepository.save(image);
        addTimeline(orderId, "Upload ảnh",
                caption != null ? caption : "Đính kèm ảnh mới", uploadedBy);

        return new RepairOrderResponse.ImageInfo(
                saved.getId(), saved.getImageUrl(), saved.getCaption(), saved.getUploadedAt());
    }

    // ── Huỷ đơn ──────────────────────────────────────────────

    @Transactional
    public RepairOrderResponse cancel(UUID orderId, String reason, UUID userId) {
        RepairOrder order = findOrderById(orderId);

        if (!order.canTransitionTo(RepairStatus.CANCELLED)) {
            throw new BusinessException(
                    STR."Không thể huỷ đơn ở trạng thái: \{order.getStatus().name()}");
        }

        order.setStatus(RepairStatus.CANCELLED);
        repairOrderRepository.save(order);
        addTimeline(orderId, "Huỷ đơn", reason, userId);

        log.info("Huỷ đơn: orderId={}, reason={}, by={}", orderId, reason, userId);
        return toResponse(order);
    }
    // ── Helpers ───────────────────────────────────────────────

    private RepairTimelineResponse toTimelineResponse(RepairTimeline tl) {
        RepairTimelineResponse.PerformerInfo performer = userRepository
                .findByIdAndIsDeletedFalse(tl.getPerformedBy())
                .map(u -> new RepairTimelineResponse.PerformerInfo(
                        u.getId(), u.getFullName(), u.getEmployeeCode(), u.getAvatarUrl()))
                .orElse(null);

        return new RepairTimelineResponse(
                tl.getId(), tl.getAction(), tl.getNote(), tl.getCreatedAt(), performer);
    }

    private String getStatusAction(RepairStatus status) {
        return switch (status) {
            case IN_PROGRESS -> "Bắt đầu sửa chữa";
            case COMPLETED -> "Hoàn thành sửa chữa";
            case DELIVERED -> "Giao hàng cho khách";
            case CANCELLED -> "Huỷ đơn";
            default -> "Cập nhật trạng thái";
        };
    }

    private RepairOrder findOrderById(UUID id) {
        return repairOrderRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn sửa chữa: " + id));
    }

    private String getUserName(UUID userId) {
        return userRepository.findByIdAndIsDeletedFalse(userId)
                .map(UserEntity::getFullName)
                .orElse("Không xác định");
    }

    private RepairOrderResponse toResponse(RepairOrder order) {
        List<RepairOrderResponse.ImageInfo> images = repairImageRepository
                .findByOrderIdAndIsDeletedFalseOrderByUploadedAtAsc(order.getId())
                .stream()
                .map(img -> new RepairOrderResponse.ImageInfo(
                        img.getId(), img.getImageUrl(), img.getCaption(), img.getUploadedAt()))
                .toList();

        return new RepairOrderResponse(
                order.getId(),
                order.getOrderCode(),
                order.getDeviceName(),
                order.getDeviceType(),
                order.getCustomerName(),
                order.getCustomerPhone(),
                order.getDescription(),
                order.getStatus().name(),
                order.getPriority(),
                toUserSummary(order.getReceivedBy()),
                toUserSummary(order.getAssignedTo()),
                order.getReceivedAt(),
                order.getEstimatedDone(),
                order.getStartedAt(),
                order.getCompletedAt(),
                order.getDeliveredAt(),
                images,
                order.getCreatedAt()
        );
    }

    private RepairOrderResponse.UserSummary toUserSummary(UUID userId) {
        if (userId == null) return null;
        return userRepository.findByIdAndIsDeletedFalse(userId)
                .map(u -> new RepairOrderResponse.UserSummary(
                        u.getId(), u.getFullName(), u.getEmployeeCode(), u.getAvatarUrl()))
                .orElse(null);
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
}
