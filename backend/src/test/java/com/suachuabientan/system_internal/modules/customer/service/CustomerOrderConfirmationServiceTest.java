package com.suachuabientan.system_internal.modules.customer.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerOrderConfirmRequest;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerOrderConfirmationResponse;
import com.suachuabientan.system_internal.modules.customer.entity.CustomerAccount;
import com.suachuabientan.system_internal.modules.customer.entity.RepairOrderConfirmation;
import com.suachuabientan.system_internal.modules.customer.repository.CustomerAccountRepository;
import com.suachuabientan.system_internal.modules.customer.repository.RepairOrderConfirmationRepository;
import com.suachuabientan.system_internal.modules.repair.entity.RepairCustomerUpdate;
import com.suachuabientan.system_internal.modules.repair.entity.RepairOrder;
import com.suachuabientan.system_internal.modules.repair.enums.RepairMediaType;
import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import com.suachuabientan.system_internal.modules.repair.repository.RepairCustomerUpdateRepository;
import com.suachuabientan.system_internal.modules.repair.repository.RepairDeviceRepository;
import com.suachuabientan.system_internal.modules.repair.repository.RepairOrderRepository;
import com.suachuabientan.system_internal.modules.repair.service.RepairMediaStorageService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CustomerOrderConfirmationServiceTest {

    @Mock
    private CustomerAccountRepository customerAccountRepository;

    @Mock
    private RepairOrderRepository repairOrderRepository;

    @Mock
    private RepairDeviceRepository repairDeviceRepository;

    @Mock
    private RepairOrderConfirmationRepository confirmationRepository;

    @Mock
    private RepairCustomerUpdateRepository repairCustomerUpdateRepository;

    @Mock
    private RepairMediaStorageService repairMediaStorageService;

    private CustomerOrderConfirmationService service;

    private UUID userId;
    private UUID customerId;
    private UUID orderId;
    private CustomerAccount account;
    private RepairOrder order;

    @BeforeEach
    void setUp() {
        service = new CustomerOrderConfirmationService(
                customerAccountRepository,
                repairOrderRepository,
                repairDeviceRepository,
                confirmationRepository,
                repairCustomerUpdateRepository,
                repairMediaStorageService,
                new ObjectMapper()
        );

        userId = UUID.randomUUID();
        customerId = UUID.randomUUID();
        orderId = UUID.randomUUID();

        account = CustomerAccount.builder()
                .userId(userId)
                .customerId(customerId)
                .contactName("A. Quang")
                .build();

        order = RepairOrder.builder()
                .orderCode("RO-20261106-005")
                .customerId(customerId)
                .deviceName("Huawei 110ktl-m0")
                .serialNumber("6T19B9071495")
                .description("Hỏng công suất vào/ra; Cháy relay đóng ngắt")
                .status(RepairStatus.CHECKED)
                .build();
        order.setId(orderId);
    }

    @Test
    void getConfirmationReturnsDefaultQuoteAndBankDetailsWhenMissing() {
        when(customerAccountRepository.findByUserIdAndActiveTrueAndIsDeletedFalse(userId))
                .thenReturn(Optional.of(account));
        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.of(order));
        when(confirmationRepository.findByOrderIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.empty());

        CustomerOrderConfirmationResponse res = service.getConfirmation(userId, orderId);

        assertEquals(orderId, res.orderId());
        assertEquals("PENDING_CUSTOMER", res.confirmationStatus());
        assertEquals(6, res.warrantyMonths());
        assertEquals("MB Bank (Quân Đội)", res.bankName());
        assertEquals("9964266771", res.accountNumber());
        assertEquals("RO-20261106-005 - 6T19B9071495", res.transferContent());
        assertEquals(List.of("Hỏng công suất vào/ra", "Cháy relay đóng ngắt"), res.diagnosisTags());
    }

    @Test
    void getConfirmationRejectsOrderOwnedByAnotherCustomer() {
        order.setCustomerId(UUID.randomUUID());
        when(customerAccountRepository.findByUserIdAndActiveTrueAndIsDeletedFalse(userId))
                .thenReturn(Optional.of(account));
        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.of(order));

        assertThrows(ResourceNotFoundException.class, () -> service.getConfirmation(userId, orderId));
    }

    @Test
    void confirmQuoteApproveWith12MonthsWarrantyAdds500kAndPublishesUpdate() {
        RepairOrderConfirmation existing = RepairOrderConfirmation.builder()
                .orderId(orderId)
                .baseAmount(4_850_000L)
                .warrantyMonths(6)
                .build();

        when(customerAccountRepository.findByUserIdAndActiveTrueAndIsDeletedFalse(userId))
                .thenReturn(Optional.of(account));
        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.of(order));
        when(confirmationRepository.findByOrderIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.of(existing));
        when(confirmationRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        CustomerOrderConfirmationResponse res = service.confirmQuote(
                userId,
                orderId,
                new CustomerOrderConfirmRequest("APPROVE", 12, null)
        );

        assertEquals("APPROVED", res.confirmationStatus());
        assertEquals(12, res.warrantyMonths());
        assertEquals(500_000L, res.warrantyExtraFee());
        assertEquals(5_350_000L, res.totalAmount());
        assertNotNull(res.approvedAt());

        ArgumentCaptor<RepairCustomerUpdate> updateCaptor = ArgumentCaptor.forClass(RepairCustomerUpdate.class);
        verify(repairCustomerUpdateRepository).save(updateCaptor.capture());
        assertTrue(updateCaptor.getValue().getTitle().contains("duyệt báo giá"));
    }

    @Test
    void confirmQuoteRejectSavesReason() {
        when(customerAccountRepository.findByUserIdAndActiveTrueAndIsDeletedFalse(userId))
                .thenReturn(Optional.of(account));
        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.of(order));
        when(confirmationRepository.findByOrderIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.empty());
        when(confirmationRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        CustomerOrderConfirmationResponse res = service.confirmQuote(
                userId,
                orderId,
                new CustomerOrderConfirmRequest("REJECT", null, "Chờ trao đổi lại phương án")
        );

        assertEquals("REJECTED", res.confirmationStatus());
        assertEquals("Chờ trao đổi lại phương án", res.rejectionReason());
        assertNotNull(res.rejectedAt());
        verify(repairCustomerUpdateRepository).save(any(RepairCustomerUpdate.class));
    }

    @Test
    void confirmQuoteThrowsOnInvalidActionOrWarranty() {
        when(customerAccountRepository.findByUserIdAndActiveTrueAndIsDeletedFalse(userId))
                .thenReturn(Optional.of(account));
        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.of(order));

        assertThrows(
                BusinessException.class,
                () -> service.confirmQuote(userId, orderId, new CustomerOrderConfirmRequest("INVALID", 6, null))
        );

        assertThrows(
                BusinessException.class,
                () -> service.confirmQuote(userId, orderId, new CustomerOrderConfirmRequest("APPROVE", 24, null))
        );
    }

    @Test
    void uploadPaymentProofStoresImageAndMarksPaymentSubmitted() {
        RepairOrderConfirmation existing = RepairOrderConfirmation.builder()
                .orderId(orderId)
                .baseAmount(4_850_000L)
                .warrantyMonths(6)
                .build();

        MockMultipartFile file = new MockMultipartFile(
                "file",
                "Bien-lai-MB-4850K.jpg",
                "image/jpeg",
                new byte[]{1, 2, 3, 4}
        );

        when(customerAccountRepository.findByUserIdAndActiveTrueAndIsDeletedFalse(userId))
                .thenReturn(Optional.of(account));
        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.of(order));
        when(confirmationRepository.findByOrderIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.of(existing));
        when(repairMediaStorageService.store(eq(file), eq(RepairMediaType.IMAGE)))
                .thenReturn(new RepairMediaStorageService.StoredMedia("/uploads/proof.jpg", "image/jpeg"));
        when(confirmationRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        CustomerOrderConfirmationResponse res = service.uploadPaymentProof(userId, orderId, file, 6, "RO-20261106-005");

        assertEquals("PAYMENT_SUBMITTED", res.confirmationStatus());
        assertEquals("/uploads/proof.jpg", res.paymentProofUrl());
        assertEquals("Bien-lai-MB-4850K.jpg", res.paymentProofFileName());
        assertEquals(4_850_000L, res.totalAmount());
        assertNotNull(res.paymentSubmittedAt());
        verify(repairCustomerUpdateRepository).save(any(RepairCustomerUpdate.class));
    }

    @Test
    void uploadPaymentProofRejectsEmptyFile() {
        MockMultipartFile emptyFile = new MockMultipartFile("file", "empty.jpg", "image/jpeg", new byte[0]);
        assertThrows(
                BusinessException.class,
                () -> service.uploadPaymentProof(userId, orderId, emptyFile, 6, null)
        );
        verifyNoInteractions(repairMediaStorageService);
    }
}
