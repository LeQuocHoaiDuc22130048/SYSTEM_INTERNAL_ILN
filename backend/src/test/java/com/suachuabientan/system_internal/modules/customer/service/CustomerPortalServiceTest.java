package com.suachuabientan.system_internal.modules.customer.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerOrderDetailResponse;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerOrderResponse;
import com.suachuabientan.system_internal.modules.customer.dto.PortalTrackRequest;
import com.suachuabientan.system_internal.modules.customer.entity.Customer;
import com.suachuabientan.system_internal.modules.customer.entity.CustomerAccount;
import com.suachuabientan.system_internal.modules.customer.repository.CustomerAccountRepository;
import com.suachuabientan.system_internal.modules.customer.repository.CustomerRepository;
import com.suachuabientan.system_internal.modules.repair.dto.request.PublishCustomerMediaRequest;
import com.suachuabientan.system_internal.modules.repair.dto.request.PublishCustomerUpdateRequest;
import com.suachuabientan.system_internal.modules.repair.entity.RepairCustomerMedia;
import com.suachuabientan.system_internal.modules.repair.entity.RepairCustomerUpdate;
import com.suachuabientan.system_internal.modules.repair.entity.RepairImage;
import com.suachuabientan.system_internal.modules.repair.entity.RepairOrder;
import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import com.suachuabientan.system_internal.modules.repair.repository.RepairCustomerMediaRepository;
import com.suachuabientan.system_internal.modules.repair.repository.RepairCustomerUpdateRepository;
import com.suachuabientan.system_internal.modules.repair.repository.RepairDeviceRepository;
import com.suachuabientan.system_internal.modules.repair.repository.RepairImageRepository;
import com.suachuabientan.system_internal.modules.repair.repository.RepairOrderRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CustomerPortalServiceTest {

    @Mock
    private CustomerAccountRepository customerAccountRepository;

    @Mock
    private CustomerRepository customerRepository;

    @Mock
    private RepairOrderRepository repairOrderRepository;

    @Mock
    private RepairDeviceRepository repairDeviceRepository;

    @Mock
    private RepairCustomerUpdateRepository repairCustomerUpdateRepository;

    @Mock
    private RepairCustomerMediaRepository repairCustomerMediaRepository;

    @Mock
    private RepairImageRepository repairImageRepository;

    @Mock
    private com.suachuabientan.system_internal.modules.auth.service.AuthService authService;

    @InjectMocks
    private CustomerPortalService service;

    private UUID userId;
    private UUID customerId;
    private UUID orderId;
    private RepairOrder order;

    @BeforeEach
    void setUp() {
        userId = UUID.randomUUID();
        customerId = UUID.randomUUID();
        orderId = UUID.randomUUID();

        order = RepairOrder.builder()
                .orderCode("RO-20261017-001")
                .customerId(customerId)
                .customerName("Khách A")
                .customerPhone("0987654321")
                .deviceName("Biến tần ABB 15kW")
                .status(RepairStatus.IN_PROGRESS)
                .receivedAt(Instant.now())
                .build();
        order.setId(orderId);
    }

    @Test
    void getMyOrders_success() {
        CustomerAccount account = CustomerAccount.builder()
                .userId(userId)
                .customerId(customerId)
                .active(true)
                .build();

        when(customerAccountRepository.findByUserIdAndActiveTrueAndIsDeletedFalse(userId))
                .thenReturn(Optional.of(account));
        when(repairOrderRepository.searchOrders(null, null, null, null, customerId.toString(), false, PageRequest.of(0, 20)))
                .thenReturn(new PageImpl<>(List.of(order)));
        when(repairDeviceRepository.findByOrderIdOrderByCreatedAtAsc(orderId))
                .thenReturn(List.of());

        Page<CustomerOrderResponse> result = service.getMyOrders(userId, null, null, PageRequest.of(0, 20));

        assertEquals(1, result.getTotalElements());
        assertEquals("RO-20261017-001", result.getContent().get(0).orderCode());
        assertEquals("Đang tiến hành sửa chữa", result.getContent().get(0).statusLabel());
    }

    @Test
    void getMyOrderDetail_success() {
        CustomerAccount account = CustomerAccount.builder()
                .userId(userId)
                .customerId(customerId)
                .active(true)
                .build();

        when(customerAccountRepository.findByUserIdAndActiveTrueAndIsDeletedFalse(userId))
                .thenReturn(Optional.of(account));
        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.of(order));
        when(repairDeviceRepository.findByOrderIdOrderByCreatedAtAsc(orderId))
                .thenReturn(List.of());
        when(repairCustomerUpdateRepository.findByOrderIdAndIsDeletedFalseOrderByPublishedAtDesc(orderId))
                .thenReturn(List.of());
        when(repairCustomerMediaRepository.findByOrderIdAndIsDeletedFalseOrderByPublishedAtDesc(orderId))
                .thenReturn(List.of());

        CustomerOrderDetailResponse result = service.getMyOrderDetail(userId, orderId);

        assertNotNull(result);
        assertEquals("RO-20261017-001", result.orderCode());
    }

    @Test
    void getMyOrderDetail_throws404_whenOrderBelongsToOtherCustomer() {
        CustomerAccount account = CustomerAccount.builder()
                .userId(userId)
                .customerId(customerId)
                .active(true)
                .build();

        RepairOrder otherCustomerOrder = RepairOrder.builder()
                .orderCode("RO-OTHER")
                .customerId(UUID.randomUUID()) // different customer
                .build();
        otherCustomerOrder.setId(UUID.randomUUID());

        when(customerAccountRepository.findByUserIdAndActiveTrueAndIsDeletedFalse(userId))
                .thenReturn(Optional.of(account));
        when(repairOrderRepository.findByIdAndIsDeletedFalse(otherCustomerOrder.getId()))
                .thenReturn(Optional.of(otherCustomerOrder));

        assertThrows(ResourceNotFoundException.class, () ->
                service.getMyOrderDetail(userId, otherCustomerOrder.getId())
        );
    }

    @Test
    void trackOrder_matchesPhoneSuffix() {
        when(repairOrderRepository.findByOrderCodeAndIsDeletedFalse("RO-20261017-001"))
                .thenReturn(Optional.of(order));
        when(repairDeviceRepository.findByOrderIdOrderByCreatedAtAsc(orderId))
                .thenReturn(List.of());
        when(repairCustomerUpdateRepository.findByOrderIdAndIsDeletedFalseOrderByPublishedAtDesc(orderId))
                .thenReturn(List.of());
        when(repairCustomerMediaRepository.findByOrderIdAndIsDeletedFalseOrderByPublishedAtDesc(orderId))
                .thenReturn(List.of());

        PortalTrackRequest request = new PortalTrackRequest("RO-20261017-001", "4321"); // 4 last digits
        CustomerOrderDetailResponse result = service.trackOrder(request);

        assertNotNull(result);
        assertEquals("RO-20261017-001", result.orderCode());
    }

    @Test
    void trackOrder_throws400_whenPhoneDoesNotMatch() {
        when(repairOrderRepository.findByOrderCodeAndIsDeletedFalse("RO-20261017-001"))
                .thenReturn(Optional.of(order));

        PortalTrackRequest request = new PortalTrackRequest("RO-20261017-001", "9999");
        BusinessException ex = assertThrows(BusinessException.class, () ->
                service.trackOrder(request)
        );
        assertEquals(400, ex.getStatusCode());
    }

    @Test
    void publishCustomerUpdate_success() {
        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.of(order));

        when(repairCustomerUpdateRepository.save(any(RepairCustomerUpdate.class)))
                .thenAnswer(inv -> {
                    RepairCustomerUpdate u = inv.getArgument(0);
                    u.setId(UUID.randomUUID());
                    return u;
                });

        PublishCustomerUpdateRequest request = new PublishCustomerUpdateRequest(
                null, "Đã thay tụ nguồn", "Đã thay xong 3 tụ 470uF 450V, đang tiến hành test tải"
        );

        var result = service.publishCustomerUpdate(orderId, request, UUID.randomUUID());
        assertNotNull(result);
        assertEquals("Đã thay tụ nguồn", result.title());
    }

    @Test
    void publishCustomerMedia_success() {
        UUID mediaId = UUID.randomUUID();
        RepairImage image = RepairImage.builder()
                .orderId(orderId)
                .imageUrl("https://minio.local/repairs/test.jpg")
                .caption("Ảnh sau sửa")
                .build();
        image.setId(mediaId);

        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId)).thenReturn(Optional.of(order));
        when(repairImageRepository.findById(mediaId)).thenReturn(Optional.of(image));
        when(repairCustomerMediaRepository.findByOrderIdAndMediaIdAndIsDeletedFalse(orderId, mediaId))
                .thenReturn(Optional.empty());
        when(repairCustomerMediaRepository.save(any(RepairCustomerMedia.class)))
                .thenAnswer(inv -> {
                    RepairCustomerMedia m = inv.getArgument(0);
                    m.setId(UUID.randomUUID());
                    return m;
                });

        PublishCustomerMediaRequest request = new PublishCustomerMediaRequest(mediaId, "Ảnh kiểm tra tải thực tế");
        var result = service.publishCustomerMedia(orderId, request, UUID.randomUUID());

        assertNotNull(result);
        assertEquals("Ảnh kiểm tra tải thực tế", result.caption());
        assertEquals("https://minio.local/repairs/test.jpg", result.mediaUrl());
    }

    @Test
    void changePassword_success() {
        CustomerAccount account = CustomerAccount.builder()
                .userId(userId)
                .customerId(customerId)
                .mustChangePassword(true)
                .active(true)
                .build();

        when(customerAccountRepository.findByUserIdAndIsDeletedFalse(userId))
                .thenReturn(Optional.of(account));

        var req = new com.suachuabientan.system_internal.modules.auth.dto.request.ChangePasswordRequest(
                "OldPass123", "NewPass123!", "NewPass123!"
        );

        service.changePassword(userId, req);

        verify(authService).changePassword(userId, req);
        assertFalse(account.isMustChangePassword());
        verify(customerAccountRepository).save(account);
    }
}

