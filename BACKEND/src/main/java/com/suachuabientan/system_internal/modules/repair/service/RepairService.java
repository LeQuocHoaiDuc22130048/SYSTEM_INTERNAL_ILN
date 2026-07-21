package com.suachuabientan.system_internal.modules.repair.service;

import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.enums.UserStatus;
import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.common.util.OrderCodeGenerator;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.repair.dto.request.AssignRequest;
import com.suachuabientan.system_internal.modules.repair.dto.request.CreateRepairDeviceRequest;
import com.suachuabientan.system_internal.modules.repair.dto.request.CreateRepairOrderRequest;
import com.suachuabientan.system_internal.modules.repair.dto.request.UpdateRepairOrderRequest;
import com.suachuabientan.system_internal.modules.repair.dto.request.ReorderRequest;
import com.suachuabientan.system_internal.modules.repair.dto.request.UpdateStatusRequest;
import com.suachuabientan.system_internal.modules.repair.dto.response.RepairDeviceResponse;
import com.suachuabientan.system_internal.modules.repair.dto.response.RepairOrderResponse;
import com.suachuabientan.system_internal.modules.repair.dto.response.RepairTimelineResponse;
import com.suachuabientan.system_internal.modules.repair.entity.RepairDevice;
import com.suachuabientan.system_internal.modules.repair.entity.RepairImage;
import com.suachuabientan.system_internal.modules.repair.entity.RepairOrder;
import com.suachuabientan.system_internal.modules.repair.entity.RepairTimeline;
import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import com.suachuabientan.system_internal.modules.repair.enums.RepairMediaType;
import com.suachuabientan.system_internal.modules.repair.repository.RepairDeviceRepository;
import com.suachuabientan.system_internal.modules.repair.repository.RepairImageRepository;
import com.suachuabientan.system_internal.modules.repair.repository.RepairOrderRepository;
import com.suachuabientan.system_internal.modules.repair.repository.RepairTimelineRepository;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import java.util.Set;
import java.util.HashSet;
import java.util.Collections;

@Slf4j
@Service
@RequiredArgsConstructor
public class RepairService {
    private final RepairOrderRepository repairOrderRepository;
    private final RepairDeviceRepository repairDeviceRepository;
    private final RepairImageRepository repairImageRepository;
    private final RepairTimelineRepository repairTimelineRepository;
    private final UserRepository userRepository;
    private final OrderCodeGenerator orderCodeGenerator;
    private final NotificationService notificationService;
    private final RepairMediaStorageService repairMediaStorageService;

    // ── Tạo đơn ──────────────────────────────────────────────

    @Transactional
    public RepairOrderResponse create(CreateRepairOrderRequest request, UUID receivedByUserId) {
        String orderCode = orderCodeGenerator.generate();

        // Lấy thông tin thiết bị đầu tiên để điền vào các field backward-compat
        CreateRepairDeviceRequest firstDevice = request.devices().get(0);

        RepairOrder order = RepairOrder.builder()
                .orderCode(orderCode)
                .deviceName(firstDevice.deviceName())
                .deviceType(firstDevice.deviceType())
                .serialNumber(firstDevice.serialNumber())
                .customerName(request.customerName())
                .customerPhone(request.customerPhone())
                .description(firstDevice.description())
                .underWarranty(Boolean.TRUE.equals(firstDevice.underWarranty()))
                .status(RepairStatus.PENDING)
                .priority(100)
                .receivedBy(receivedByUserId)
                .receivedAt(Instant.now())
                .build();

        RepairOrder saved = repairOrderRepository.save(order);

        // Lưu danh sách thiết bị
        List<RepairDevice> deviceEntities = request.devices().stream()
                .map(d -> buildDevice(d, saved))
                .toList();
        repairDeviceRepository.saveAll(deviceEntities);

        // Ghi timeline
        addTimeline(saved.getId(), "Tiếp nhận đơn",
                STR."Đơn \{orderCode} được tạo bởi \{getUserName(receivedByUserId)}",
                receivedByUserId);

        log.info("Tạo đơn sửa chữa: orderCode={}, devices={}, by={}", orderCode, deviceEntities.size(), receivedByUserId);
        notifyNewRepairOrder(saved);
        return toResponse(saved);
    }

    // ── Danh sách & tìm kiếm ─────────────────────────────────

    @Transactional(readOnly = true)
    public Page<RepairOrderResponse> getAll(
            String keyword, RepairStatus status, UUID assignedTo, Pageable pageable, CustomUserDetails userDetails) {
        String staffIdStr = null;
        if (userDetails != null && !userDetails.isManagerOrAbove() && !userDetails.hasRole("EMPLOYEE") && !userDetails.hasRole("TECHNICIAN")) {
            staffIdStr = userDetails.getUserId().toString();
        }
        String statusStr = status != null ? status.name() : null;
        String assignedToStr = assignedTo != null ? assignedTo.toString() : null;
        return repairOrderRepository
                .searchOrders(keyword, statusStr, assignedToStr, staffIdStr, pageable)
                .map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public RepairOrderResponse getById(UUID id, CustomUserDetails userDetails) {
        RepairOrder order = findOrderById(id);
        if (userDetails != null && !userDetails.isManagerOrAbove() && !userDetails.hasRole("EMPLOYEE") && !userDetails.hasRole("TECHNICIAN")) {
            UUID userId = userDetails.getUserId();
            if (!userId.equals(order.getReceivedBy()) && !userId.equals(order.getAssignedTo()) && 
                (order.getAssignees() == null || !order.getAssignees().contains(userId))) {
                throw new BusinessException("Bạn không có quyền truy cập đơn hàng này", 403);
            }
        }
        return toResponse(order);
    }

    // ── Phân công kỹ thuật viên ───────────────────────────────

    @Transactional
    public RepairOrderResponse assign(UUID orderId, AssignRequest request, UUID managerId) {
        RepairOrder order = findOrderById(orderId);

        // Lấy danh sách ID kỹ thuật viên cần phân công
        List<UUID> technicianIds = new ArrayList<>();
        if (request.technicianIds() != null) {
            technicianIds.addAll(request.technicianIds());
        }
        if (request.technicianId() != null && !technicianIds.contains(request.technicianId())) {
            technicianIds.add(request.technicianId());
        }

        // Lấy danh sách kỹ thuật viên đã được phân công trước đó để gửi thông báo chuyển đơn
        UUID previousAssignee = order.getAssignedTo();
        Set<UUID> previousAssignees = new HashSet<>();
        if (order.getAssignees() != null) {
            previousAssignees.addAll(order.getAssignees());
        }
        if (previousAssignee != null) {
            previousAssignees.add(previousAssignee);
        }

        // Cập nhật assignees
        if (order.getAssignees() == null) {
            order.setAssignees(new HashSet<>());
        }
        order.getAssignees().clear();

        String note;
        List<UserEntity> technicians = new ArrayList<>();
        if (technicianIds.isEmpty()) {
            order.setAssignedTo(null);
            note = "Hủy phân công người sửa chữa";
        } else {
            // Kiểm tra kỹ thuật viên hợp lệ
            for (UUID techId : technicianIds) {
                UserEntity technician = userRepository.findByIdAndIsDeletedFalse(techId)
                        .orElseThrow(() -> new ResourceNotFoundException(
                                STR."Không tìm thấy kỹ thuật viên: \{techId}"));
                if (technician.getRole() != UserRole.EMPLOYEE && technician.getRole() != UserRole.TECHNICIAN) {
                    throw new BusinessException(STR."Chỉ nhân viên hoặc kỹ thuật viên mới được phân công sửa chữa: \{technician.getFullName()}");
                }
                if (technician.getStatus() != UserStatus.ACTIVE) {
                    throw new BusinessException(STR."Nhân viên được phân công phải đang hoạt động: \{technician.getFullName()}");
                }
                technicians.add(technician);
            }

            order.getAssignees().addAll(technicianIds);
            order.setAssignedTo(technicianIds.get(0));

            List<String> names = technicians.stream().map(UserEntity::getFullName).toList();
            String namesJoined = String.join(", ", names);

            note = previousAssignee == null
                    ? STR."Phân công cho \{namesJoined}"
                    : STR."Thay đổi phân công sang \{namesJoined}";
        }

        if (request.note() != null) note += STR." — \{request.note()}";

        addTimeline(orderId, "Phân công kỹ thuật viên", note, managerId);
        log.info("Phân công đơn: orderId={}, technicians={}, by={}", orderId, technicianIds, managerId);

        RepairOrder saved = repairOrderRepository.save(order);

        // Đồng bộ người được phân công của đơn hàng với thiết bị
        List<RepairDevice> devices = repairDeviceRepository.findByOrderIdOrderByCreatedAtAsc(saved.getId());
        if (!devices.isEmpty()) {
            for (RepairDevice d : devices) {
                d.setAssignedTo(saved.getAssignedTo());
            }
            repairDeviceRepository.saveAll(devices);
        }

        // Gửi thông báo cho nhân viên mới được phân công
        for (UserEntity technician : technicians) {
            notifyOrderAssigned(saved, technician);
        }

        // Gửi thông báo chuyển đơn cho những nhân viên bị xóa khỏi danh sách phân công
        Set<UUID> removedTechs = new HashSet<>(previousAssignees);
        removedTechs.removeAll(technicianIds);

        for (UUID techId : removedTechs) {
            notificationService.sendToUser(
                    techId,
                    NotificationType.ORDER_ASSIGNED,
                    "Chuyen don sua chua cho nhan vien khac",
                    STR."Đơn \{order.getOrderCode()} đã được chuyển giao cho nhân viên khác.",
                    "REPAIR_ORDER",
                    order.getId().toString(),
                    false);
        }

        return toResponse(saved);
    }

    // ── Cập nhật trạng thái ───────────────────────────────────

    @Transactional
    public RepairOrderResponse updateStatus(UUID orderId, UpdateStatusRequest request, CustomUserDetails userDetails) {
        RepairOrder order = findOrderById(orderId);

        // Validate transition hợp lệ
        if (!order.canTransitionTo(request.status())) {
            throw new BusinessException(
                    STR."Không thể chuyển từ \{order.getStatus().name()} sang \{request.status().name()}");
        }

        UUID userId = userDetails != null ? userDetails.getUserId() : null;

        // Kiểm tra quyền: nhân viên chỉ được thao tác trên đơn hàng được phân công hoặc tiếp nhận
        if (userDetails != null && !userDetails.isManagerOrAbove() && !userDetails.hasRole("TECHNICIAN")) {
            if (userId == null || (!userId.equals(order.getReceivedBy()) && !userId.equals(order.getAssignedTo()) && 
                (order.getAssignees() == null || !order.getAssignees().contains(userId)))) {
                throw new BusinessException("Bạn không có quyền cập nhật trạng thái đơn hàng này", 403);
            }
        }

        // Kiểm tra quyền: chỉ người được assign mới có thể cập nhật CHECKING/IN_PROGRESS/COMPLETED
        if ((request.status() == RepairStatus.CHECKING
                || request.status() == RepairStatus.IN_PROGRESS
                || request.status() == RepairStatus.COMPLETED)
                && (userDetails != null && !userDetails.isManagerOrAbove() && !userDetails.hasRole("TECHNICIAN"))
                && (userId == null || (!userId.equals(order.getAssignedTo()) && 
                (order.getAssignees() == null || !order.getAssignees().contains(userId))))) {
            throw new BusinessException("Chỉ kỹ thuật viên được phân công mới có thể cập nhật trạng thái này");
        }

        // Kiểm tra quyền hủy: chỉ SUPER_ADMIN hoặc ADMIN mới có thể hủy
        if (request.status() == RepairStatus.CANCELLED) {
            if (userDetails == null || (!userDetails.hasRole("SUPER_ADMIN") && !userDetails.hasRole("ADMIN"))) {
                throw new BusinessException("Chỉ quản trị viên mới có quyền hủy đơn hàng", 403);
            }
        }

        RepairStatus oldStatus = order.getStatus();
        order.setStatus(request.status());

        // Đồng bộ trạng thái thiết bị của đơn hàng
        List<RepairDevice> devices = repairDeviceRepository.findByOrderIdOrderByCreatedAtAsc(order.getId());
        if (!devices.isEmpty()) {
            for (RepairDevice d : devices) {
                d.setStatus(request.status());
            }
            repairDeviceRepository.saveAll(devices);
        }

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

        notifyStatusChanged(order, oldStatus);
        return toResponse(order);
    }

    // ── Sắp xếp ưu tiên (kéo thả) ────────────────────────────

    @Transactional
    public void reorder(ReorderRequest request, UUID managerId) {
        request.items().forEach(item -> {
            repairOrderRepository.updatePriority(item.orderId(), item.priority());
            repairOrderRepository.findByIdAndIsDeletedFalse(item.orderId())
                    .filter(order -> order.getAssignedTo() != null)
                    .ifPresent(order -> notifyPriorityChanged(order, item.priority()));
        });

        log.info("Cập nhật priority {} đơn bởi managerId={}", request.items().size(), managerId);
        addTimeline(
                request.items().get(0).orderId(),
                "Thay đổi ưu tiên",
                STR."Manager sắp xếp lại thứ tự \{request.items().size()} đơn",
                managerId);
    }

    // ── Timeline ──────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<RepairTimelineResponse> getTimeline(UUID orderId, CustomUserDetails userDetails) {
        RepairOrder order = findOrderById(orderId); // Validate tồn tại
        if (userDetails != null && !userDetails.isManagerOrAbove() && !userDetails.hasRole("EMPLOYEE") && !userDetails.hasRole("TECHNICIAN")) {
            UUID userId = userDetails.getUserId();
            if (!userId.equals(order.getReceivedBy()) && !userId.equals(order.getAssignedTo()) && 
                (order.getAssignees() == null || !order.getAssignees().contains(userId))) {
                throw new BusinessException("Bạn không có quyền truy cập lịch sử đơn hàng này", 403);
            }
        }
        return repairTimelineRepository.findByOrderIdOrderByCreatedAtDesc(orderId)
                .stream().map(this::toTimelineResponse).toList();
    }

    // ── Ảnh đính kèm ─────────────────────────────────────────

    @Transactional
    public RepairOrderResponse.ImageInfo addImage(
            UUID orderId, String imageUrl, String caption, CustomUserDetails userDetails) {
        RepairOrder order = findOrderById(orderId); // Validate tồn tại
        if (userDetails != null && !userDetails.isManagerOrAbove() && !userDetails.hasRole("TECHNICIAN")) {
            UUID userId = userDetails.getUserId();
            if (!userId.equals(order.getReceivedBy()) && !userId.equals(order.getAssignedTo()) && 
                (order.getAssignees() == null || !order.getAssignees().contains(userId))) {
                throw new BusinessException("Bạn không có quyền thêm hình ảnh vào đơn hàng này", 403);
            }
        }
        UUID uploadedBy = userDetails != null ? userDetails.getUserId() : null;

        RepairImage image = RepairImage.builder()
                .orderId(orderId)
                .imageUrl(imageUrl)
                .mediaType(RepairMediaType.IMAGE)
                .caption(caption)
                .uploadedBy(uploadedBy)
                .uploadedAt(Instant.now())
                .build();

        RepairImage saved = repairImageRepository.save(image);
        addTimeline(orderId, "Upload ảnh",
                caption != null ? caption : "Đính kèm ảnh mới", uploadedBy);

        return new RepairOrderResponse.ImageInfo(
                saved.getId(), saved.getImageUrl(), saved.getMediaType().name(), saved.getCaption(), saved.getUploadedAt());
    }

    @Transactional
    public RepairOrderResponse.ImageInfo addMedia(
            UUID orderId, MultipartFile file, RepairMediaType mediaType, String caption, CustomUserDetails userDetails) {
        RepairOrder order = findOrderById(orderId);
        if (userDetails != null && !userDetails.isManagerOrAbove() && !userDetails.hasRole("TECHNICIAN")) {
            UUID userId = userDetails.getUserId();
            if (!userId.equals(order.getReceivedBy()) && !userId.equals(order.getAssignedTo()) && 
                (order.getAssignees() == null || !order.getAssignees().contains(userId))) {
                throw new BusinessException("Bạn không có quyền tải phương tiện lên đơn hàng này", 403);
            }
        }
        UUID uploadedBy = userDetails != null ? userDetails.getUserId() : null;
        RepairMediaStorageService.StoredMedia storedMedia = repairMediaStorageService.store(file, mediaType);

        RepairImage media = RepairImage.builder()
                .orderId(orderId)
                .imageUrl(storedMedia.publicUrl())
                .mediaType(mediaType)
                .caption(caption)
                .uploadedBy(uploadedBy)
                .uploadedAt(Instant.now())
                .build();

        RepairImage saved = repairImageRepository.save(media);
        String action = mediaType == RepairMediaType.VIDEO ? "Upload video" : "Upload anh";
        addTimeline(orderId, action, caption != null ? caption : storedMedia.originalFileName(), uploadedBy);

        return new RepairOrderResponse.ImageInfo(
                saved.getId(), saved.getImageUrl(), saved.getMediaType().name(), saved.getCaption(), saved.getUploadedAt());
    }

    @Transactional
    public void deleteMedia(UUID mediaId, CustomUserDetails userDetails) {
        RepairImage image = repairImageRepository.findById(mediaId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy hình ảnh/video: " + mediaId));
        
        RepairOrder order = repairOrderRepository.findByIdAndIsDeletedFalse(image.getOrderId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn sửa chữa tương ứng"));

        UUID userId = userDetails.getUserId();
        if (!userDetails.isManagerOrAbove() && !userDetails.hasRole("TECHNICIAN")
                && !userId.equals(image.getUploadedBy())
                && !userId.equals(order.getAssignedTo())
                && (order.getAssignees() == null || !order.getAssignees().contains(userId))) {
            throw new BusinessException("Bạn không có quyền xóa hình ảnh/video này", 403);
        }

        image.softDelete(userId);
        repairImageRepository.save(image);
        
        String mediaLabel = image.getMediaType() == RepairMediaType.VIDEO ? "video" : "ảnh";
        addTimeline(order.getId(), STR."Xóa \{mediaLabel}", image.getCaption(), userId);
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
        
        // Đồng bộ trạng thái thiết bị của đơn hàng
        List<RepairDevice> devices = repairDeviceRepository.findByOrderIdOrderByCreatedAtAsc(order.getId());
        if (!devices.isEmpty()) {
            for (RepairDevice d : devices) {
                d.setStatus(RepairStatus.CANCELLED);
            }
            repairDeviceRepository.saveAll(devices);
        }

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
            case WAITING_FOR_CHECK -> "Chờ kiểm tra";
            case CHECKING -> "Bắt đầu kiểm tra";
            case CHECKED -> "Đã kiểm tra";
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
                        img.getId(), img.getImageUrl(), img.getMediaType().name(), img.getCaption(), img.getUploadedAt()))
                .toList();

        List<RepairOrderResponse.UserSummary> assigneesList = java.util.Collections.emptyList();
        if (order.getAssignees() != null && !order.getAssignees().isEmpty()) {
            assigneesList = order.getAssignees().stream()
                    .map(this::toUserSummary)
                    .filter(Objects::nonNull)
                    .toList();
        }

        // Map danh sách thiết bị
        List<RepairDeviceResponse> deviceResponses = repairDeviceRepository
                .findByOrderIdOrderByCreatedAtAsc(order.getId())
                .stream()
                .map(d -> new RepairDeviceResponse(
                        d.getId(),
                        d.getDeviceName(),
                        d.getDeviceType(),
                        d.getSerialNumber(),
                        d.getUnderWarranty(),
                        d.getWarrantyExpiry(),
                        d.getDescription(),
                        d.getStatus().name(),
                        toUserSummary(d.getAssignedTo()),
                        d.getCreatedAt()))
                .toList();

        List<RepairTimeline> timeline = repairTimelineRepository.findByOrderIdOrderByCreatedAtDesc(order.getId());
        String latestNote = "";
        for (RepairTimeline tl : timeline) {
            if (tl.getNote() != null && !tl.getNote().isBlank()) {
                String rawNote = tl.getNote();
                String action = tl.getAction();
                if (rawNote.contains(" — ")) {
                    latestNote = rawNote.substring(rawNote.lastIndexOf(" — ") + 3).trim();
                    break;
                } else if (!"Chỉnh sửa thông tin".equals(action) && 
                           !"Phân công kỹ thuật viên".equals(action) && 
                           !"Xóa đơn hàng".equals(action) &&
                           !"Tiếp nhận đơn".equals(action) &&
                           !"Thay đổi ưu tiên".equals(action) &&
                           !"Upload ảnh".equals(action) &&
                           !"Upload anh".equals(action) &&
                           !"Upload video".equals(action) &&
                           !"Xóa ảnh".equals(action) &&
                           !"Xóa video".equals(action)) {
                    latestNote = rawNote;
                    break;
                }
            }
        }

        return new RepairOrderResponse(
                order.getId(),
                order.getOrderCode(),
                order.getDeviceName(),
                order.getDeviceType(),
                order.getSerialNumber(),
                order.getCustomerName(),
                order.getCustomerPhone(),
                order.getDescription(),
                order.getStatus().name(),
                order.getPriority(),
                toUserSummary(order.getReceivedBy()),
                toUserSummary(order.getAssignedTo()),
                assigneesList,
                order.getReceivedAt(),
                order.getEstimatedDone(),
                order.getStartedAt(),
                order.getCompletedAt(),
                order.getDeliveredAt(),
                order.getUnderWarranty(),
                images,
                order.getCreatedAt(),
                deviceResponses,
                latestNote
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

    private void notifyNewRepairOrder(RepairOrder order) {
        notificationService.sendToRoles(
                managerRoles(),
                NotificationType.NEW_REPAIR_ORDER,
                "Đơn sửa chữa mới",
                STR."Đơn \{order.getOrderCode()} của khách \{order.getCustomerName()} đang chờ phân công.",
                "REPAIR_ORDER",
                order.getId().toString(),
                true);
    }

    private void notifyOrderAssigned(RepairOrder order, UserEntity technician) {
        notificationService.sendToUser(
                technician.getId(),
                NotificationType.ORDER_ASSIGNED,
                "Bạn được phân công đơn mới",
                STR."Đơn \{order.getOrderCode()} - \{order.getDeviceName()} đã được phân công cho bạn.",
                "REPAIR_ORDER",
                order.getId().toString(),
                true);
    }

    private void notifyStatusChanged(RepairOrder order, RepairStatus oldStatus) {
        if (order.getStatus() == RepairStatus.COMPLETED) {
            notificationService.sendToUser(
                    order.getReceivedBy(),
                    NotificationType.ORDER_COMPLETED,
                    "Đơn sửa chữa đã hoàn thành",
                    STR."Đơn \{order.getOrderCode()} đã sửa xong và sẵn sàng giao khách.",
                    "REPAIR_ORDER",
                    order.getId().toString(),
                    true);
            return;
        }

        if (order.getAssignees() != null && !Objects.equals(oldStatus, order.getStatus())) {
            for (UUID techId : order.getAssignees()) {
                notificationService.sendToUser(
                        techId,
                        NotificationType.ORDER_STATUS_CHANGED,
                        "Trạng thái đơn đã thay đổi",
                        STR."Đơn \{order.getOrderCode()} chuyển từ \{oldStatus.name()} sang \{order.getStatus().name()}.",
                        "REPAIR_ORDER",
                        order.getId().toString(),
                        false);
            }
        }
    }

    private void notifyPriorityChanged(RepairOrder order, Integer priority) {
        if (order.getAssignees() != null) {
            for (UUID techId : order.getAssignees()) {
                notificationService.sendToUser(
                        techId,
                        NotificationType.ORDER_PRIORITY_CHANGED,
                        "Uu tien don da thay doi",
                        STR."Đơn \{order.getOrderCode()} được cập nhật mức ưu tiên \{priority}.",
                        "REPAIR_ORDER",
                        order.getId().toString(),
                        false);
            }
        }
    }

    @Transactional
    public RepairOrderResponse update(UUID id, UpdateRepairOrderRequest request, CustomUserDetails userDetails) {
        RepairOrder order = findOrderById(id);

        // Cập nhật thông tin khách hàng
        order.setCustomerName(request.customerName());
        order.setCustomerPhone(request.customerPhone());

        // Cập nhật backward-compat fields từ thiết bị đầu tiên
        if (request.devices() != null && !request.devices().isEmpty()) {
            CreateRepairDeviceRequest first = request.devices().get(0);
            order.setDeviceName(first.deviceName());
            order.setDeviceType(first.deviceType());
            order.setSerialNumber(first.serialNumber());
            order.setDescription(first.description());
            order.setUnderWarranty(Boolean.TRUE.equals(first.underWarranty()));
        }

        RepairOrder saved = repairOrderRepository.save(order);

        // Xóa devices cũ và tạo lại
        if (request.devices() != null && !request.devices().isEmpty()) {
            repairDeviceRepository.deleteByOrderId(saved.getId());
            List<RepairDevice> newDevices = request.devices().stream()
                    .map(d -> buildDevice(d, saved))
                    .toList();
            if (!newDevices.isEmpty()) {
                newDevices.get(0).setAssignedTo(saved.getAssignedTo());
            }
            repairDeviceRepository.saveAll(newDevices);
        }

        UUID performerId = userDetails != null ? userDetails.getUserId() : null;
        String timelineNote = STR."Thông tin đơn \{order.getOrderCode()} đã được chỉnh sửa bởi \{getUserName(performerId)}";
        if (request.note() != null) {
            timelineNote += STR." — \{request.note()}";
        }
        addTimeline(order.getId(), "Chỉnh sửa thông tin", timelineNote, performerId);

        log.info("Chỉnh sửa thông tin đơn: id={}, by={}", id, performerId);
        return toResponse(saved);
    }

    @Transactional
    public void delete(UUID id, CustomUserDetails userDetails) {
        RepairOrder order = findOrderById(id);
        UUID performerId = userDetails != null ? userDetails.getUserId() : null;
        order.softDelete(performerId);
        repairOrderRepository.save(order);

        // Ghi timeline
        addTimeline(order.getId(), "Xóa đơn hàng",
                STR."Đơn \{order.getOrderCode()} đã bị xóa bởi \{getUserName(performerId)}",
                performerId);
        log.info("Xóa đơn sửa chữa: id={}, by={}", id, performerId);
    }

    private List<UserRole> managerRoles() {
        return List.of(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.MANAGER);
    }

    /** Xây dựng RepairDevice entity từ DTO request */
    private RepairDevice buildDevice(CreateRepairDeviceRequest d, RepairOrder order) {
        UUID assignedToId = null;
        if (d.assignedToId() != null && !d.assignedToId().isBlank()) {
            try { assignedToId = UUID.fromString(d.assignedToId()); } catch (Exception ignored) {}
        }
        return RepairDevice.builder()
                .order(order)
                .deviceName(d.deviceName())
                .deviceType(d.deviceType())
                .serialNumber(d.serialNumber())
                .underWarranty(Boolean.TRUE.equals(d.underWarranty()))
                .warrantyExpiry(d.warrantyExpiry())
                .description(d.description())
                .status(RepairStatus.PENDING)
                .assignedTo(assignedToId)
                .priority(100)
                .createdAt(Instant.now())
                .build();
    }
}

