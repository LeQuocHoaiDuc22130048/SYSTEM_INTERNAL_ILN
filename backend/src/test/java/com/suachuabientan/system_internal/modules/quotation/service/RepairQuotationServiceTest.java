package com.suachuabientan.system_internal.modules.quotation.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.modules.customer.dto.PortalSupportConfigResponse;
import com.suachuabientan.system_internal.modules.customer.entity.Customer;
import com.suachuabientan.system_internal.modules.customer.entity.CustomerAccount;
import com.suachuabientan.system_internal.modules.customer.repository.CustomerAccountRepository;
import com.suachuabientan.system_internal.modules.customer.repository.CustomerRepository;
import com.suachuabientan.system_internal.modules.customer.service.PortalSupportConfigService;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import com.suachuabientan.system_internal.modules.quotation.dto.*;
import com.suachuabientan.system_internal.modules.quotation.entity.RepairPaymentProof;
import com.suachuabientan.system_internal.modules.quotation.entity.RepairQuotation;
import com.suachuabientan.system_internal.modules.quotation.enums.PaymentProofStatus;
import com.suachuabientan.system_internal.modules.quotation.enums.QuotationItemDecision;
import com.suachuabientan.system_internal.modules.quotation.enums.QuotationStatus;
import com.suachuabientan.system_internal.modules.quotation.repository.RepairPaymentProofRepository;
import com.suachuabientan.system_internal.modules.quotation.repository.RepairQuotationItemRepository;
import com.suachuabientan.system_internal.modules.quotation.repository.RepairQuotationRepository;
import com.suachuabientan.system_internal.modules.repair.entity.RepairOrder;
import com.suachuabientan.system_internal.modules.repair.enums.RepairMediaType;
import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import com.suachuabientan.system_internal.modules.repair.repository.RepairOrderRepository;
import com.suachuabientan.system_internal.modules.repair.repository.RepairTimelineRepository;
import com.suachuabientan.system_internal.modules.repair.service.RepairMediaStorageService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class RepairQuotationServiceTest {

    @Mock private RepairQuotationRepository quotationRepository;
    @Mock private RepairQuotationItemRepository quotationItemRepository;
    @Mock private RepairPaymentProofRepository paymentProofRepository;
    @Mock private RepairOrderRepository repairOrderRepository;
    @Mock private RepairTimelineRepository repairTimelineRepository;
    @Mock private CustomerRepository customerRepository;
    @Mock private CustomerAccountRepository customerAccountRepository;
    @Mock private PortalSupportConfigService portalSupportConfigService;
    @Mock private NotificationService notificationService;
    @Mock private RepairMediaStorageService repairMediaStorageService;

    private RepairQuotationService service;
    private UUID staffId;
    private UUID customerUserId;
    private UUID customerId;
    private Customer customer;
    private CustomerAccount customerAccount;

    @BeforeEach
    void setUp() {
        service = new RepairQuotationService(
                quotationRepository,
                quotationItemRepository,
                paymentProofRepository,
                repairOrderRepository,
                repairTimelineRepository,
                customerRepository,
                customerAccountRepository,
                portalSupportConfigService,
                notificationService,
                repairMediaStorageService,
                new ObjectMapper()
        );

        staffId = UUID.randomUUID();
        customerUserId = UUID.randomUUID();
        customerId = UUID.randomUUID();

        customer = new Customer();
        customer.setId(customerId);
        customer.setCustomerCode("KH-001");
        customer.setCustomerName("Anh Quang Solar");
        customer.setPhone("0909123456");

        customerAccount = CustomerAccount.builder()
                .userId(customerUserId)
                .customerId(customerId)
                .contactName("A. Quang")
                .active(true)
                .build();

        lenient().when(portalSupportConfigService.getSupportConfig()).thenReturn(
                PortalSupportConfigResponse.builder()
                        .bankName("MB Bank (Quân Đội)")
                        .bankBin("970422")
                        .bankAccountNumber("9964266771")
                        .bankAccountHolder("CONG TY TNHH KY THUAT CONG NGHE")
                        .build()
        );
        lenient().when(paymentProofRepository.findByQuotationIdAndIsDeletedFalseOrderByCreatedAtDesc(any()))
                .thenReturn(List.of());
    }

    @Test
    void createQuotation_multiDeviceSameCustomer_calculatesTotalsAndSends() {
        UUID orderId1 = UUID.randomUUID();
        UUID orderId2 = UUID.randomUUID();

        RepairOrder order1 = RepairOrder.builder()
                .orderCode("RO-20261113-001")
                .deviceName("Huawei 110ktl-m0")
                .serialNumber("SN-001")
                .customerId(customerId)
                .customerName("Anh Quang Solar")
                .status(RepairStatus.CHECKED)
                .receivedBy(staffId)
                .receivedAt(Instant.now())
                .build();
        order1.setId(orderId1);

        RepairOrder order2 = RepairOrder.builder()
                .orderCode("RO-20261113-002")
                .deviceName("Sungrow SG110CX")
                .serialNumber("SN-002")
                .customerId(customerId)
                .customerName("Anh Quang Solar")
                .status(RepairStatus.CHECKED)
                .receivedBy(staffId)
                .receivedAt(Instant.now())
                .build();
        order2.setId(orderId2);

        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId1)).thenReturn(Optional.of(order1));
        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId2)).thenReturn(Optional.of(order2));
        when(quotationItemRepository.findOrderIdsWithActiveQuotations(any(), any())).thenReturn(List.of());
        when(customerRepository.findByIdAndIsDeletedFalse(customerId)).thenReturn(Optional.of(customer));
        when(quotationRepository.existsByQuoteCode(any())).thenReturn(false);
        when(quotationRepository.save(any())).thenAnswer(inv -> {
            RepairQuotation q = inv.getArgument(0);
            if (q.getId() == null) q.setId(UUID.randomUUID());
            q.getItems().forEach(i -> {
                if (i.getId() == null) i.setId(UUID.randomUUID());
            });
            return q;
        });
        when(customerAccountRepository.findByCustomerIdAndIsDeletedFalseOrderByCreatedAtDesc(customerId))
                .thenReturn(List.of(customerAccount));

        CreateQuotationRequest request = new CreateQuotationRequest(
                customerId,
                null,
                "Gửi duyệt 2 máy",
                null,
                true,
                List.of(
                        new CreateQuotationItemRequest(
                                orderId1,
                                List.of(new DiagnosedErrorDto("Hỏng công suất vào/ra", "HIGH")),
                                List.of(
                                        new QuotationLineItemRequest("Thay Module IGBT", 2, new BigDecimal("1600000")),
                                        new QuotationLineItemRequest("Công kỹ thuật", 1, new BigDecimal("700000"))
                                ),
                                null
                        ),
                        new CreateQuotationItemRequest(
                                orderId2,
                                List.of(new DiagnosedErrorDto("Cháy relay", "MEDIUM")),
                                List.of(new QuotationLineItemRequest("Thay cụm Relay", 1, new BigDecimal("950000"))),
                                null
                        )
                )
        );

        QuotationResponse response = service.createQuotation(request, staffId);

        assertEquals(QuotationStatus.SENT, response.status());
        assertEquals(2, response.itemCount());
        assertEquals(0, new BigDecimal("4850000").compareTo(response.totalEstimatedAmount()));
        assertEquals(0, new BigDecimal("3900000").compareTo(response.items().get(0).baseCost()));
        assertEquals(2, response.items().get(0).warrantyOptions().size());
        assertNotNull(response.bankInfo().vietQrPayload());
        assertFalse(response.bankInfo().vietQrPayload().isBlank());
        verify(repairTimelineRepository, times(2)).save(any());
        verify(notificationService, times(1)).sendToUser(eq(customerUserId), any(), any(), any(), any(), any(), eq(true));
    }

    @Test
    void createQuotation_differentCustomers_throwsBusinessException() {
        UUID orderId1 = UUID.randomUUID();
        UUID orderId2 = UUID.randomUUID();
        RepairOrder order1 = RepairOrder.builder().orderCode("RO-1").deviceName("M1").customerId(customerId).status(RepairStatus.CHECKED).build();
        order1.setId(orderId1);
        RepairOrder order2 = RepairOrder.builder().orderCode("RO-2").deviceName("M2").customerId(UUID.randomUUID()).status(RepairStatus.CHECKED).build();
        order2.setId(orderId2);

        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId1)).thenReturn(Optional.of(order1));
        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId2)).thenReturn(Optional.of(order2));

        CreateQuotationRequest request = new CreateQuotationRequest(
                null, null, null, null, true,
                List.of(
                        new CreateQuotationItemRequest(orderId1, List.of(), List.of(new QuotationLineItemRequest("A", 1, BigDecimal.TEN)), null),
                        new CreateQuotationItemRequest(orderId2, List.of(), List.of(new QuotationLineItemRequest("B", 1, BigDecimal.TEN)), null)
                )
        );

        assertThrows(BusinessException.class, () -> service.createQuotation(request, staffId));
    }

    @Test
    void respondToQuotation_partialApproval_updatesOrdersAndTotalsCorrectly() {
        UUID quotationId = UUID.randomUUID();
        UUID orderId1 = UUID.randomUUID();
        UUID orderId2 = UUID.randomUUID();

        RepairOrder order1 = RepairOrder.builder()
                .orderCode("RO-20261113-001").deviceName("Huawei 110ktl").customerId(customerId)
                .status(RepairStatus.CHECKED).receivedBy(staffId).build();
        order1.setId(orderId1);

        RepairOrder order2 = RepairOrder.builder()
                .orderCode("RO-20261113-002").deviceName("Sungrow 110CX").customerId(customerId)
                .status(RepairStatus.CHECKED).receivedBy(staffId).build();
        order2.setId(orderId2);

        String warrantyJson = "[{\"code\":\"STANDARD_6M\",\"label\":\"Bảo hành 6 tháng\",\"description\":\"Gói tiêu chuẩn\",\"months\":6,\"fee\":0}," +
                "{\"code\":\"EXTENDED_12M\",\"label\":\"Bảo hành 1 năm\",\"description\":\"Toàn diện\",\"months\":12,\"fee\":500000}]";

        var item1 = com.suachuabientan.system_internal.modules.quotation.entity.RepairQuotationItem.builder()
                .repairOrderId(orderId1).orderCode("RO-20261113-001").deviceName("Huawei 110ktl")
                .baseCost(new BigDecimal("4850000")).warrantyOptionsJson(warrantyJson)
                .decision(QuotationItemDecision.PENDING).build();
        item1.setId(UUID.randomUUID());

        var item2 = com.suachuabientan.system_internal.modules.quotation.entity.RepairQuotationItem.builder()
                .repairOrderId(orderId2).orderCode("RO-20261113-002").deviceName("Sungrow 110CX")
                .baseCost(new BigDecimal("2000000")).warrantyOptionsJson(warrantyJson)
                .decision(QuotationItemDecision.PENDING).build();
        item2.setId(UUID.randomUUID());

        RepairQuotation quotation = RepairQuotation.builder()
                .quoteCode("QT-20261113-001")
                .customerId(customerId)
                .customerName("Anh Quang Solar")
                .status(QuotationStatus.SENT)
                .totalEstimatedAmount(new BigDecimal("6850000"))
                .items(List.of(item1, item2))
                .build();
        quotation.setId(quotationId);
        quotation.setCreatedBy(staffId);

        when(customerAccountRepository.findByUserIdAndActiveTrueAndIsDeletedFalse(customerUserId))
                .thenReturn(Optional.of(customerAccount));
        when(quotationRepository.findByIdAndCustomerIdAndIsDeletedFalse(quotationId, customerId))
                .thenReturn(Optional.of(quotation));
        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId1)).thenReturn(Optional.of(order1));
        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId2)).thenReturn(Optional.of(order2));
        when(quotationRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        RespondQuotationRequest request = new RespondQuotationRequest(List.of(
                new QuotationItemDecisionRequest(item1.getId(), QuotationItemDecision.APPROVED, "EXTENDED_12M", null),
                new QuotationItemDecisionRequest(item2.getId(), QuotationItemDecision.REJECTED, null, "Chi phí cao")
        ));

        QuotationResponse response = service.respondToQuotation(quotationId, customerUserId, request);

        assertEquals(QuotationStatus.PARTIAL_APPROVED, response.status());
        assertEquals(1, response.approvedItemCount());
        assertEquals(1, response.rejectedItemCount());
        assertEquals(0, new BigDecimal("5350000").compareTo(response.totalApprovedAmount()));
        assertEquals(RepairStatus.IN_PROGRESS, order1.getStatus());
        assertEquals(RepairStatus.CANCELLED, order2.getStatus());

        // Second submission must fail (idempotency)
        assertThrows(BusinessException.class, () -> service.respondToQuotation(quotationId, customerUserId, request));
    }

    @Test
    void submitAndVerifyPaymentProof_happyPath() {
        UUID quotationId = UUID.randomUUID();
        RepairQuotation quotation = RepairQuotation.builder()
                .quoteCode("QT-20261113-001")
                .customerId(customerId)
                .customerName("Anh Quang Solar")
                .status(QuotationStatus.APPROVED)
                .totalApprovedAmount(new BigDecimal("5350000"))
                .items(List.of())
                .build();
        quotation.setId(quotationId);
        quotation.setCreatedBy(staffId);

        MockMultipartFile file = new MockMultipartFile("file", "receipt.jpg", "image/jpeg", new byte[]{1, 2, 3});

        when(customerAccountRepository.findByUserIdAndActiveTrueAndIsDeletedFalse(customerUserId))
                .thenReturn(Optional.of(customerAccount));
        when(quotationRepository.findByIdAndCustomerIdAndIsDeletedFalse(quotationId, customerId))
                .thenReturn(Optional.of(quotation));
        when(repairMediaStorageService.store(any(), eq(RepairMediaType.IMAGE)))
                .thenReturn(new RepairMediaStorageService.StoredMedia("/api/v1/repair-media/abc.jpg", "receipt.jpg"));
        when(paymentProofRepository.save(any())).thenAnswer(inv -> {
            RepairPaymentProof p = inv.getArgument(0);
            if (p.getId() == null) p.setId(UUID.randomUUID());
            return p;
        });

        PaymentProofResponse proofRes = service.submitPaymentProof(quotationId, customerUserId, file, null, "Đã CK");
        assertEquals(PaymentProofStatus.PENDING_VERIFY, proofRes.status());
        assertEquals("QT-20261113-001", proofRes.transferContent());
        assertEquals(0, new BigDecimal("5350000").compareTo(proofRes.amount()));

        RepairPaymentProof storedProof = RepairPaymentProof.builder()
                .quotationId(quotationId)
                .amount(new BigDecimal("5350000"))
                .transferContent("QT-20261113-001")
                .proofFileUrl("/api/v1/repair-media/abc.jpg")
                .status(PaymentProofStatus.PENDING_VERIFY)
                .build();
        storedProof.setId(proofRes.id());

        when(paymentProofRepository.findByIdAndIsDeletedFalse(proofRes.id())).thenReturn(Optional.of(storedProof));
        when(quotationRepository.findByIdAndIsDeletedFalse(quotationId)).thenReturn(Optional.of(quotation));

        PaymentProofResponse verified = service.verifyPaymentProof(proofRes.id(), staffId, new VerifyPaymentProofRequest(true, null));
        assertEquals(PaymentProofStatus.VERIFIED, verified.status());
        assertEquals(staffId, verified.verifiedBy());
    }
}
