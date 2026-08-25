package com.suachuabientan.system_internal.modules.warehouse.service;

import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.AdjustStockRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.PartCheckoutRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.PartCheckoutHistoryResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.PartResponse;
import com.suachuabientan.system_internal.modules.warehouse.entity.Part;
import com.suachuabientan.system_internal.modules.warehouse.entity.PartCheckout;
import com.suachuabientan.system_internal.modules.warehouse.entity.PartLot;
import com.suachuabientan.system_internal.modules.warehouse.entity.StoreLocation;
import com.suachuabientan.system_internal.modules.warehouse.enums.CheckoutStatus;
import com.suachuabientan.system_internal.modules.warehouse.repository.PartCheckoutRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.PartLotRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.PartRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.StockMovementRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.StoreLocationRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PartServiceTest {

    @Mock
    private PartRepository partRepository;

    @Mock
    private PartLotRepository partLotRepository;

    @Mock
    private StoreLocationRepository storeLocationRepository;

    @Mock
    private StockMovementRepository stockMovementRepository;

    @Mock
    private PartCheckoutRepository partCheckoutRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private NotificationService notificationService;

    @Mock
    private JdbcTemplate jdbcTemplate;

    @Mock
    private com.suachuabientan.system_internal.modules.warehouse.repository.BoardItemRepository boardItemRepository;

    @InjectMocks
    private PartService partService;

    private UUID userId;
    private UUID partId;
    private UUID locationId;
    private UUID lotId;

    @BeforeEach
    void setUp() {
        userId = UUID.randomUUID();
        partId = UUID.randomUUID();
        locationId = UUID.randomUUID();
        lotId = UUID.randomUUID();
    }

    @Test
    @DisplayName("Xuất kho làm số lượng còn lại <= minAmount sẽ tự động gửi cảnh báo PART_LOW_STOCK_ALERT")
    void checkoutPart_TriggersLowStockNotification() {
        Part part = Part.builder()
                .ipn("IGBT-60N100")
                .name("IGBT 60N100")
                .minAmount(new BigDecimal("10"))
                .measurementUnit("Cái")
                .build();
        part.setId(partId);

        StoreLocation location = StoreLocation.builder()
                .code("KHO-A1")
                .name("Kệ A1")
                .build();
        location.setId(locationId);

        PartLot lot = PartLot.builder()
                .partId(partId)
                .storeLocationId(locationId)
                .amount(new BigDecimal("12"))
                .build();
        lot.setId(lotId);

        when(partRepository.findByIdAndIsDeletedFalse(partId)).thenReturn(Optional.of(part));
        when(storeLocationRepository.findByIdAndIsDeletedFalse(locationId)).thenReturn(Optional.of(location));
        when(partLotRepository.findByPartIdAndStoreLocationIdAndIsDeletedFalse(partId, locationId)).thenReturn(Optional.of(lot));

        PartCheckout checkout = PartCheckout.builder()
                .partId(partId)
                .partLotId(lotId)
                .storeLocationId(locationId)
                .takenBy(userId)
                .quantity(new BigDecimal("5"))
                .returnedQuantity(BigDecimal.ZERO)
                .takenAt(Instant.now())
                .purpose("Sửa biến tần")
                .checkoutStatus(CheckoutStatus.OPEN)
                .build();
        checkout.setId(UUID.randomUUID());
        when(partCheckoutRepository.save(any(PartCheckout.class))).thenReturn(checkout);

        // Khi checkAndNotifyLowStock chạy, nó tìm các lot để tính tổng:
        when(partLotRepository.findByPartIdAndIsDeletedFalse(partId)).thenReturn(List.of(lot));

        PartCheckoutRequest request = new PartCheckoutRequest(
                locationId,
                null,
                new BigDecimal("5"),
                "Sửa biến tần",
                null,
                "Test checkout"
        );

        PartCheckoutHistoryResponse response = partService.checkoutPart(partId, request, userId);

        assertNotNull(response);
        // Sau khi xuất 5 cái, số lượng trong lot còn 7 (12 - 5), mà minAmount = 10 -> Cần gửi cảnh báo
        assertEquals(new BigDecimal("7"), lot.getAmount());

        ArgumentCaptor<String> titleCaptor = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> bodyCaptor = ArgumentCaptor.forClass(String.class);

        verify(notificationService, times(1)).sendToRoles(
                anyCollection(),
                eq(NotificationType.PART_LOW_STOCK_ALERT),
                titleCaptor.capture(),
                bodyCaptor.capture(),
                eq("PART"),
                eq(partId.toString()),
                eq(true)
        );

        assertTrue(titleCaptor.getValue().contains("Cảnh báo tồn kho tối thiểu"));
        assertTrue(bodyCaptor.getValue().contains("chỉ còn 7"));
    }

    @Test
    @DisplayName("Điều chỉnh tồn kho về 0 sẽ gửi thông báo Hết hàng")
    void adjustStock_TriggersOutOfStockNotification() {
        Part part = Part.builder()
                .ipn("CAP-470UF")
                .name("Tụ 470uF 450V")
                .minAmount(new BigDecimal("5"))
                .measurementUnit("Cái")
                .build();
        part.setId(partId);

        StoreLocation location = StoreLocation.builder()
                .code("KHO-B1")
                .name("Kệ B1")
                .build();
        location.setId(locationId);

        PartLot lot = PartLot.builder()
                .partId(partId)
                .storeLocationId(locationId)
                .amount(BigDecimal.ZERO)
                .build();
        lot.setId(lotId);

        when(partRepository.findByIdAndIsDeletedFalse(partId)).thenReturn(Optional.of(part));
        when(storeLocationRepository.findByCodeIgnoreCaseAndIsDeletedFalse("KHO-B1")).thenReturn(Optional.of(location));
        when(partLotRepository.findByPartIdAndStoreLocationIdAndIsDeletedFalse(partId, locationId)).thenReturn(Optional.of(lot));
        when(partLotRepository.findByPartIdAndIsDeletedFalse(partId)).thenReturn(List.of(lot));

        AdjustStockRequest request = new AdjustStockRequest("KHO-B1", BigDecimal.ZERO, "Kiểm kê kho");
        PartResponse response = partService.adjustStock(partId, request, userId);

        assertNotNull(response);

        ArgumentCaptor<String> titleCaptor = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> bodyCaptor = ArgumentCaptor.forClass(String.class);

        verify(notificationService, times(1)).sendToRoles(
                anyCollection(),
                eq(NotificationType.PART_LOW_STOCK_ALERT),
                titleCaptor.capture(),
                bodyCaptor.capture(),
                eq("PART"),
                eq(partId.toString()),
                eq(true)
        );

        assertTrue(titleCaptor.getValue().contains("Hết hàng"));
        assertTrue(bodyCaptor.getValue().contains("HẾT HÀNG trong kho"));
    }

    @Test
    @DisplayName("Quét QR vị trí kho không phân biệt hoa thường và hậu tố _QR")
    void scanLocationQr_CaseInsensitive_Success() {
        StoreLocation loc = StoreLocation.builder()
                .code("LOC1")
                .name("Kệ 1")
                .qrCode("LOC1")
                .isFull(false)
                .build();
        loc.setId(locationId);

        Part part = Part.builder()
                .ipn("IGBT-60N100")
                .name("Transistor 60N100")
                .build();
        part.setId(partId);

        PartLot lot = PartLot.builder()
                .partId(partId)
                .storeLocationId(locationId)
                .amount(new BigDecimal("100"))
                .build();
        lot.setId(lotId);

        when(storeLocationRepository.findAllByCodeOrQrCodeIgnoreCase("loc1")).thenReturn(List.of(loc));
        when(partLotRepository.findByStoreLocationIdInAndIsDeletedFalse(List.of(locationId))).thenReturn(List.of(lot));
        when(partRepository.findByIdAndIsDeletedFalse(partId)).thenReturn(Optional.of(part));

        var res = partService.scanLocationQr("loc1");

        assertNotNull(res);
        assertEquals("LOC1", res.code());
        assertEquals(1, res.totalPartTypes());
        assertEquals(new BigDecimal("100"), res.totalQuantity());
        assertEquals(1, res.parts().size());
        assertEquals("IGBT-60N100", res.parts().get(0).ipn());
        assertEquals(new BigDecimal("100"), res.parts().get(0).amount());
    }

    @Test
    @DisplayName("Tiến trình quét tất cả linh kiện scanAndNotifyAllLowStockParts hoạt động chính xác")
    void scanAndNotifyAllLowStockParts_Success() {
        Part p1 = Part.builder().ipn("IPN-1").name("Part 1").minAmount(new BigDecimal("10")).measurementUnit("Cái").build();
        p1.setId(UUID.randomUUID());
        Part p2 = Part.builder().ipn("IPN-2").name("Part 2").minAmount(BigDecimal.ZERO).build(); // minAmount = 0 -> bỏ qua
        p2.setId(UUID.randomUUID());

        PartLot lot1 = PartLot.builder().partId(p1.getId()).amount(new BigDecimal("3")).build();

        when(partRepository.findByIsDeletedFalse()).thenReturn(List.of(p1, p2));
        when(partLotRepository.findByPartIdAndIsDeletedFalse(p1.getId())).thenReturn(List.of(lot1));

        int alerted = partService.scanAndNotifyAllLowStockParts();

        assertEquals(1, alerted);
        verify(notificationService, times(1)).sendToRoles(
                anyCollection(),
                eq(NotificationType.PART_LOW_STOCK_ALERT),
                anyString(),
                anyString(),
                eq("PART"),
                eq(p1.getId().toString()),
                eq(true)
        );
    }
}
