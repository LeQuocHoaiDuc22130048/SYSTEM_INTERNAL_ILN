package com.suachuabientan.system_internal.modules.customer.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.customer.dto.*;
import com.suachuabientan.system_internal.modules.customer.entity.Customer;
import com.suachuabientan.system_internal.modules.customer.entity.CustomerAccount;
import com.suachuabientan.system_internal.modules.customer.repository.CustomerAccountRepository;
import com.suachuabientan.system_internal.modules.customer.repository.CustomerRepository;
import com.suachuabientan.system_internal.modules.repair.dto.request.PublishCustomerMediaRequest;
import com.suachuabientan.system_internal.modules.repair.dto.request.PublishCustomerUpdateRequest;
import com.suachuabientan.system_internal.modules.repair.entity.RepairDevice;
import com.suachuabientan.system_internal.modules.repair.entity.RepairImage;
import com.suachuabientan.system_internal.modules.repair.entity.RepairOrder;
import com.suachuabientan.system_internal.modules.repair.entity.RepairCustomerMedia;
import com.suachuabientan.system_internal.modules.repair.entity.RepairCustomerUpdate;
import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import com.suachuabientan.system_internal.modules.repair.repository.RepairDeviceRepository;
import com.suachuabientan.system_internal.modules.repair.repository.RepairImageRepository;
import com.suachuabientan.system_internal.modules.auth.dto.request.ChangePasswordRequest;
import com.suachuabientan.system_internal.modules.auth.service.AuthService;
import com.suachuabientan.system_internal.modules.repair.repository.RepairOrderRepository;
import com.suachuabientan.system_internal.modules.repair.repository.RepairCustomerMediaRepository;
import com.suachuabientan.system_internal.modules.repair.repository.RepairCustomerUpdateRepository;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.repair.enums.RepairMediaType;
import com.suachuabientan.system_internal.modules.repair.service.RepairMediaStorageService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class CustomerPortalService {

    private final CustomerAccountRepository customerAccountRepository;
    private final CustomerRepository customerRepository;
    private final RepairOrderRepository repairOrderRepository;
    private final RepairDeviceRepository repairDeviceRepository;
    private final RepairCustomerUpdateRepository repairCustomerUpdateRepository;
    private final RepairCustomerMediaRepository repairCustomerMediaRepository;
    private final RepairImageRepository repairImageRepository;
    private final AuthService authService;
    private final UserRepository userRepository;
    private final RepairMediaStorageService repairMediaStorageService;

    @Transactional(readOnly = true)
    public CustomerAccountProfileResponse getAccountProfile(UUID userId) {
        CustomerAccount account = customerAccountRepository.findByUserIdAndActiveTrueAndIsDeletedFalse(userId)
                .orElseThrow(() -> new BusinessException("Tài khoản chưa được liên kết với hồ sơ khách hàng nào hoặc đã bị khóa", 403));

        UserEntity user = userRepository.findByIdAndIsDeletedFalse(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy thông tin tài khoản: " + userId));

        Customer customer = customerRepository.findByIdAndIsDeletedFalse(account.getCustomerId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy hồ sơ khách hàng: " + account.getCustomerId()));

        return new CustomerAccountProfileResponse(
                user.getId(),
                user.getUsername(),
                account.getContactName() != null ? account.getContactName() : user.getFullName(),
                account.getPhone() != null ? account.getPhone() : user.getPhone(),
                account.getEmail(),
                user.getAvatarUrl(),
                customer.getId(),
                customer.getCustomerCode(),
                customer.getCustomerName(),
                customer.getAddress(),
                customer.getTaxCode()
        );
    }

    @Transactional
    public CustomerAccountProfileResponse updateAccountProfile(UUID userId, UpdateCustomerAccountProfileRequest request) {
        CustomerAccount account = customerAccountRepository.findByUserIdAndActiveTrueAndIsDeletedFalse(userId)
                .orElseThrow(() -> new BusinessException("Tài khoản chưa được liên kết với hồ sơ khách hàng nào hoặc đã bị khóa", 403));

        UserEntity user = userRepository.findByIdAndIsDeletedFalse(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy thông tin tài khoản: " + userId));

        String contactName = request.contactName() != null ? request.contactName().strip() : "";
        String phone = request.phone() != null && !request.phone().isBlank() ? request.phone().strip() : null;
        String email = request.email() != null && !request.email().isBlank() ? request.email().strip() : null;

        user.setFullName(contactName);
        if (phone != null) {
            user.setPhone(phone);
        }
        userRepository.save(user);

        account.setContactName(contactName);
        account.setPhone(phone);
        account.setEmail(email);
        customerAccountRepository.save(account);

        return getAccountProfile(userId);
    }

    @Transactional
    public CustomerAccountProfileResponse updateAvatar(UUID userId, MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException("Tệp tải lên không được để trống", 400);
        }

        CustomerAccount account = customerAccountRepository.findByUserIdAndActiveTrueAndIsDeletedFalse(userId)
                .orElseThrow(() -> new BusinessException("Tài khoản chưa được liên kết với hồ sơ khách hàng nào hoặc đã bị khóa", 403));

        UserEntity user = userRepository.findByIdAndIsDeletedFalse(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy thông tin tài khoản: " + userId));

        RepairMediaStorageService.StoredMedia stored = repairMediaStorageService.store(file, RepairMediaType.IMAGE);
        user.setAvatarUrl(stored.publicUrl());
        userRepository.save(user);

        return getAccountProfile(userId);
    }

    @Transactional(readOnly = true)
    public UUID getCurrentCustomerId(UUID userId) {
        CustomerAccount account = customerAccountRepository.findByUserIdAndActiveTrueAndIsDeletedFalse(userId)
                .orElseThrow(() -> new BusinessException("Tài khoản chưa được liên kết với hồ sơ khách hàng nào hoặc đã bị khóa", 403));
        return account.getCustomerId();
    }

    @Transactional(readOnly = true)
    public CustomerResponse getMyProfile(UUID userId) {
        UUID customerId = getCurrentCustomerId(userId);
        Customer customer = customerRepository.findByIdAndIsDeletedFalse(customerId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy hồ sơ khách hàng: " + customerId));
        return new CustomerResponse(
                customer.getId(),
                customer.getCustomerCode(),
                customer.getCustomerName(),
                customer.getType(),
                customer.getPhone(),
                customer.getEmail(),
                customer.getAddress(),
                customer.getTaxCode(),
                customer.getNotes(),
                customer.isActive(),
                customer.getCreatedAt(),
                customer.getUpdatedAt()
        );
    }

    @Transactional(readOnly = true)
    public Page<CustomerOrderResponse> getMyOrders(UUID userId, String keyword, RepairStatus status, Pageable pageable) {
        UUID customerId = getCurrentCustomerId(userId);
        String statusStr = status != null ? status.name() : null;
        return repairOrderRepository.searchOrders(keyword, statusStr, null, null, customerId.toString(), false, pageable)
                .map(this::toOrderSummary);
    }

    @Transactional(readOnly = true)
    public CustomerOrderDetailResponse getMyOrderDetail(UUID userId, UUID orderId) {
        UUID customerId = getCurrentCustomerId(userId);
        RepairOrder order = repairOrderRepository.findByIdAndIsDeletedFalse(orderId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn hàng: " + orderId));

        if (order.getCustomerId() == null || !order.getCustomerId().equals(customerId)) {
            throw new ResourceNotFoundException("Không tìm thấy đơn hàng: " + orderId);
        }

        return buildOrderDetail(order);
    }

    @Transactional(readOnly = true)
    public CustomerOrderDetailResponse trackOrder(PortalTrackRequest request) {
        String orderCode = request.orderCode().strip();
        RepairOrder order = repairOrderRepository.findByOrderCodeAndIsDeletedFalse(orderCode)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn hàng: " + orderCode));

        String queryPhoneDigits = extractDigits(request.phone());
        if (queryPhoneDigits.isEmpty() || queryPhoneDigits.length() < 4) {
            throw new BusinessException("Vui lòng nhập tối thiểu 4 số cuối của số điện thoại", 400);
        }

        boolean matched = false;
        if (order.getCustomerPhone() != null) {
            String orderPhoneDigits = extractDigits(order.getCustomerPhone());
            if (orderPhoneDigits.equals(queryPhoneDigits) || orderPhoneDigits.endsWith(queryPhoneDigits)) {
                matched = true;
            }
        }

        if (!matched && order.getCustomerId() != null) {
            Customer customer = customerRepository.findByIdAndIsDeletedFalse(order.getCustomerId()).orElse(null);
            if (customer != null && customer.getPhone() != null) {
                String customerPhoneDigits = extractDigits(customer.getPhone());
                if (customerPhoneDigits.equals(queryPhoneDigits) || customerPhoneDigits.endsWith(queryPhoneDigits)) {
                    matched = true;
                }
            }
        }

        if (!matched) {
            throw new BusinessException("Số điện thoại xác thực không khớp với thông tin đơn hàng", 400);
        }

        return buildOrderDetail(order);
    }

    @Transactional
    public CustomerUpdateResponse publishCustomerUpdate(UUID orderId, PublishCustomerUpdateRequest request, UUID publishedBy) {
        RepairOrder order = repairOrderRepository.findByIdAndIsDeletedFalse(orderId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn hàng: " + orderId));

        String message = request.resolveMessage();
        if (message.isBlank()) {
            throw new BusinessException("Nội dung cập nhật không được để trống", 400);
        }

        RepairCustomerUpdate update = RepairCustomerUpdate.builder()
                .orderId(order.getId())
                .deviceId(request.deviceId())
                .title(request.title().strip())
                .message(message)
                .statusAtTime(order.getStatus() != null ? order.getStatus().name() : null)
                .publishedBy(publishedBy)
                .publishedAt(Instant.now())
                .build();

        RepairCustomerUpdate saved = repairCustomerUpdateRepository.save(update);
        return toUpdateResponse(saved);
    }

    @Transactional
    public void changePassword(UUID userId, ChangePasswordRequest request) {
        authService.changePassword(userId, request);
        customerAccountRepository.findByUserIdAndIsDeletedFalse(userId)
                .ifPresent(account -> {
                    account.setMustChangePassword(false);
                    customerAccountRepository.save(account);
                });
    }

    @Transactional
    public CustomerMediaResponse publishCustomerMedia(UUID orderId, PublishCustomerMediaRequest request, UUID publishedBy) {
        RepairOrder order = repairOrderRepository.findByIdAndIsDeletedFalse(orderId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn hàng: " + orderId));

        RepairImage image = repairImageRepository.findById(request.mediaId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tệp đính kèm: " + request.mediaId()));

        if (!image.getOrderId().equals(order.getId())) {
            throw new BusinessException("Hình ảnh không thuộc đơn hàng này", 400);
        }

        RepairCustomerMedia media = repairCustomerMediaRepository.findByOrderIdAndMediaIdAndIsDeletedFalse(order.getId(), request.mediaId())
                .orElseGet(() -> RepairCustomerMedia.builder()
                        .orderId(order.getId())
                        .mediaId(request.mediaId())
                        .publishedBy(publishedBy)
                        .publishedAt(Instant.now())
                        .build());

        media.setCaption(request.caption() != null ? request.caption().strip() : image.getCaption());
        RepairCustomerMedia saved = repairCustomerMediaRepository.save(media);

        return new CustomerMediaResponse(
                saved.getId(),
                saved.getMediaId(),
                image.getImageUrl(),
                saved.getCaption(),
                saved.getPublishedAt()
        );
    }

    @Transactional(readOnly = true)
    public List<CustomerUpdateResponse> getPublishedUpdates(UUID orderId) {
        return repairCustomerUpdateRepository.findByOrderIdAndIsDeletedFalseOrderByPublishedAtDesc(orderId).stream()
                .map(this::toUpdateResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<CustomerMediaResponse> getPublishedMedia(UUID orderId) {
        List<RepairCustomerMedia> mediaList = repairCustomerMediaRepository.findByOrderIdAndIsDeletedFalseOrderByPublishedAtDesc(orderId);
        List<RepairImage> orderImages = repairImageRepository.findByOrderIdAndIsDeletedFalseOrderByUploadedAtAsc(orderId);

        if (mediaList.isEmpty() && orderImages.isEmpty()) {
            return List.of();
        }

        Map<UUID, RepairImage> imageMap = orderImages.stream()
                .collect(Collectors.toMap(RepairImage::getId, Function.identity(), (a, b) -> a));

        Map<UUID, RepairCustomerMedia> publishedMap = mediaList.stream()
                .collect(Collectors.toMap(RepairCustomerMedia::getMediaId, Function.identity(), (a, b) -> a));

        List<CustomerMediaResponse> result = new java.util.ArrayList<>();
        // 1. Uu tien cac anh duoc cong bo rieng voi chu thich danh cho khach hang
        for (RepairCustomerMedia m : mediaList) {
            RepairImage img = imageMap.get(m.getMediaId());
            if (img != null) {
                String url = img.getImageUrl() != null ? img.getImageUrl() : "";
                result.add(new CustomerMediaResponse(m.getId(), m.getMediaId(), url, m.getCaption(), m.getPublishedAt()));
            }
        }

        // 2. Tu dong bo sung cac anh kiem tra cua don hang neu chua co trong danh sach tren
        for (RepairImage img : orderImages) {
            if (!publishedMap.containsKey(img.getId())) {
                String caption = img.getCaption() != null && !img.getCaption().isBlank()
                        ? img.getCaption()
                        : "Ảnh kiểm tra thiết bị";
                result.add(new CustomerMediaResponse(
                        img.getId(),
                        img.getId(),
                        img.getImageUrl(),
                        caption,
                        img.getUploadedAt() != null ? img.getUploadedAt() : Instant.now()
                ));
            }
        }

        return result;
    }

    private CustomerOrderDetailResponse buildOrderDetail(RepairOrder order) {
        List<RepairDevice> deviceEntities = repairDeviceRepository.findByOrderIdOrderByCreatedAtAsc(order.getId());
        List<CustomerDeviceResponse> devices = deviceEntities.stream()
                .map(d -> new CustomerDeviceResponse(
                        d.getId(),
                        d.getDeviceName(),
                        d.getDeviceType(),
                        d.getSerialNumber(),
                        d.getDescription(),
                        d.getStatus(),
                        CustomerOrderResponse.getFriendlyStatusLabel(d.getStatus()),
                        d.getUnderWarranty()
                ))
                .toList();

        List<CustomerUpdateResponse> updates = getPublishedUpdates(order.getId());
        List<CustomerMediaResponse> media = getPublishedMedia(order.getId());

        return new CustomerOrderDetailResponse(
                order.getId(),
                order.getOrderCode(),
                order.getStatus(),
                CustomerOrderResponse.getFriendlyStatusLabel(order.getStatus()),
                order.getReceivedAt(),
                order.getEstimatedDone(),
                order.getCompletedAt(),
                order.getDeliveredAt(),
                order.getCustomerName(),
                order.getDescription(),
                devices,
                updates,
                media
        );
    }

    private CustomerOrderResponse toOrderSummary(RepairOrder order) {
        List<RepairDevice> devices = repairDeviceRepository.findByOrderIdOrderByCreatedAtAsc(order.getId());
        return new CustomerOrderResponse(
                order.getId(),
                order.getOrderCode(),
                order.getDeviceName(),
                order.getDeviceType(),
                order.getSerialNumber(),
                order.getStatus(),
                CustomerOrderResponse.getFriendlyStatusLabel(order.getStatus()),
                order.getReceivedAt(),
                order.getEstimatedDone(),
                order.getCompletedAt(),
                order.getDeliveredAt(),
                devices.size()
        );
    }

    private CustomerUpdateResponse toUpdateResponse(RepairCustomerUpdate u) {
        return new CustomerUpdateResponse(
                u.getId(),
                u.getTitle(),
                u.getMessage(),
                u.getStatusAtTime(),
                u.getPublishedAt()
        );
    }

    private String extractDigits(String input) {
        if (input == null) return "";
        return input.replaceAll("[^0-9]", "");
    }
}
