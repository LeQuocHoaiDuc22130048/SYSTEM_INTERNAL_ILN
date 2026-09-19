package com.suachuabientan.system_internal.modules.warehouse.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.modules.warehouse.repository.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

@ExtendWith(MockitoExtension.class)
class UnifiedWarehouseServiceTest {

    @Mock
    private BoardItemRepository boardItemRepository;
    @Mock
    private PartRepository partRepository;
    @Mock
    private PartLotRepository partLotRepository;
    @Mock
    private StoreLocationRepository storeLocationRepository;
    @Mock
    private BoardCheckoutRepository boardCheckoutRepository;
    @Mock
    private com.suachuabientan.system_internal.modules.auth.repository.UserRepository userRepository;
    @Mock
    private WarehouseService warehouseService;
    @Mock
    private PartService partService;

    @InjectMocks
    private UnifiedWarehouseService unifiedWarehouseService;

    private UUID itemId;
    private UUID userId;

    @BeforeEach
    void setUp() {
        itemId = UUID.randomUUID();
        userId = UUID.randomUUID();
    }

    @Test
    @DisplayName("Bug 1: Unified checkout cho PART với số lượng âm (-5) bị từ chối bằng BusinessException")
    void checkoutUnifiedItem_Part_NegativeQuantity_ThrowsBusinessException() {
        Map<String, Object> payload = Map.of(
                "quantity", -5,
                "storeLocationId", UUID.randomUUID().toString()
        );

        BusinessException ex = assertThrows(BusinessException.class, () ->
                unifiedWarehouseService.checkoutUnifiedItem(itemId, "PART", payload, userId)
        );
        assertTrue(ex.getMessage().contains("lớn hơn 0"));
    }

    @Test
    @DisplayName("Bug 1: Unified checkout cho BOARD với số lượng âm (-3) bị từ chối bằng BusinessException")
    void checkoutUnifiedItem_Board_NegativeQuantity_ThrowsBusinessException() {
        Map<String, Object> payload = Map.of(
                "quantity", -3
        );

        BusinessException ex = assertThrows(BusinessException.class, () ->
                unifiedWarehouseService.checkoutUnifiedItem(itemId, "BOARD", payload, userId)
        );
        assertTrue(ex.getMessage().contains("lớn hơn 0"));
    }
}
