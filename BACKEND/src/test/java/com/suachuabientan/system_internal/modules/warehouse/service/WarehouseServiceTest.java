package com.suachuabientan.system_internal.modules.warehouse.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.util.QrCodeGenerator;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.CreateBoardItemRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.BoardItemResponse;
import com.suachuabientan.system_internal.modules.warehouse.entity.BoardItem;
import com.suachuabientan.system_internal.modules.warehouse.repository.BoardCheckoutRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.BoardItemRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.PartRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.StockMovementRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.StoreLocationRepository;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class WarehouseServiceTest {

    @Mock
    private BoardItemRepository boardItemRepository;

    @Mock
    private BoardCheckoutRepository boardCheckoutRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private QrCodeGenerator qrCodeGenerator;

    @Mock
    private PartRepository partRepository;

    @Mock
    private StoreLocationRepository storeLocationRepository;

    @Mock
    private StockMovementRepository stockMovementRepository;

    @Mock
    private JdbcTemplate jdbcTemplate;

    @InjectMocks
    private WarehouseService warehouseService;

    private UUID userId;

    @BeforeEach
    void setUp() {
        userId = UUID.randomUUID();
        lenient().when(storeLocationRepository.save(any())).thenAnswer(invocation -> {
            com.suachuabientan.system_internal.modules.warehouse.entity.StoreLocation loc = invocation.getArgument(0);
            loc.setId(UUID.randomUUID());
            return loc;
        });
    }

    @Test
    @DisplayName("Tạo bo mạch thành công với dữ liệu hợp lệ")
    void createBoard_Success() {
        CreateBoardItemRequest request = new CreateBoardItemRequest(
                "Bo nguồn 24V",
                "Power Board",
                "Mô tả bo nguồn",
                "KHO-A1",
                "SN-12345",
                "MODEL-X",
                "POWER",
                "v1.0",
                null,
                null,
                "Ghi chú",
                null,
                null,
                1
        );

        when(qrCodeGenerator.generateQrCode()).thenReturn("BOARD-12345678");
        when(boardItemRepository.existsByQrCodeAndIsDeletedFalse("BOARD-12345678")).thenReturn(false);
        when(boardItemRepository.existsBySerialNumberAndIsDeletedFalse("SN-12345")).thenReturn(false);

        BoardItem savedItem = BoardItem.builder()
                .qrCode("BOARD-12345678")
                .name(request.name())
                .category(request.category())
                .serialNumber("SN-12345")
                .model(request.model())
                .quantity(1)
                .build();
        savedItem.setId(UUID.randomUUID());

        when(boardItemRepository.save(any(BoardItem.class))).thenReturn(savedItem);

        BoardItemResponse response = warehouseService.create(request, userId);

        assertNotNull(response);
        assertEquals("BOARD-12345678", response.qrCode());
        assertEquals("Bo nguồn 24V", response.name());
        assertEquals("SN-12345", response.serialNumber());
    }

    @Test
    @DisplayName("Tạo bo mạch với serialNumber rỗng sẽ tự động chuyển thành null để tránh trùng UNIQUE key trong DB")
    void createBoard_EmptySerialNumber_NormalizedToNull() {
        CreateBoardItemRequest request = new CreateBoardItemRequest(
                "Bo điều khiển",
                "Control Board",
                null,
                "KHO-B2",
                "   ",
                "MODEL-Y",
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                2
        );

        when(qrCodeGenerator.generateQrCode()).thenReturn("BOARD-87654321");
        when(boardItemRepository.existsByQrCodeAndIsDeletedFalse("BOARD-87654321")).thenReturn(false);

        BoardItem savedItem = BoardItem.builder()
                .qrCode("BOARD-87654321")
                .name(request.name())
                .serialNumber(null)
                .quantity(2)
                .build();
        savedItem.setId(UUID.randomUUID());

        when(boardItemRepository.save(any(BoardItem.class))).thenReturn(savedItem);

        BoardItemResponse response = warehouseService.create(request, userId);

        assertNotNull(response);

        ArgumentCaptor<BoardItem> itemCaptor = ArgumentCaptor.forClass(BoardItem.class);
        verify(boardItemRepository).save(itemCaptor.capture());
        assertNull(itemCaptor.getValue().getSerialNumber());
    }

    @Test
    @DisplayName("Tạo bo mạch trùng số serial ném lỗi BusinessException 409 thay vì 500 hệ thống")
    void createBoard_DuplicateSerialNumber_ThrowsBusinessException() {
        CreateBoardItemRequest request = new CreateBoardItemRequest(
                "Bo nguồn 24V",
                "Power Board",
                null,
                "KHO-A1",
                "SN-DUPLICATE",
                "MODEL-X",
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                1
        );

        when(qrCodeGenerator.generateQrCode()).thenReturn("BOARD-12345678");
        when(boardItemRepository.existsByQrCodeAndIsDeletedFalse("BOARD-12345678")).thenReturn(false);
        when(boardItemRepository.existsBySerialNumberAndIsDeletedFalse("SN-DUPLICATE")).thenReturn(true);

        BusinessException ex = assertThrows(BusinessException.class, () -> warehouseService.create(request, userId));
        assertEquals(409, ex.getStatusCode());
        assertTrue(ex.getMessage().contains("SN-DUPLICATE"));
        verify(boardItemRepository, never()).save(any());
    }
}
