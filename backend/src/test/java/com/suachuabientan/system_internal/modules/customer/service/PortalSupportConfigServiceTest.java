package com.suachuabientan.system_internal.modules.customer.service;

import com.suachuabientan.system_internal.modules.customer.dto.PortalSupportConfigResponse;
import com.suachuabientan.system_internal.modules.customer.dto.UpdatePortalSupportConfigRequest;
import com.suachuabientan.system_internal.modules.customer.entity.PortalSupportConfig;
import com.suachuabientan.system_internal.modules.customer.repository.PortalSupportConfigRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PortalSupportConfigServiceTest {

    @Mock
    private PortalSupportConfigRepository repository;

    @InjectMocks
    private PortalSupportConfigService service;

    private PortalSupportConfig sampleConfig;
    private final UUID defaultConfigId = UUID.fromString("00000000-0000-0000-0000-000000000001");

    @BeforeEach
    void setUp() {
        sampleConfig = PortalSupportConfig.builder()
                .id(defaultConfigId)
                .hotlineNumber("0909111222")
                .hotlineLabel("Hotline CSKH")
                .zaloUrl("https://zalo.me/0909111222")
                .zaloLabel("Zalo OA CSKH")
                .workingHours("08:00 - 17:30")
                .workshopAddress("Khu công nghiệp Tân Bình")
                .updatedAt(LocalDateTime.now())
                .build();
    }

    @Test
    void getSupportConfig_returnsExistingConfig() {
        when(repository.findById(defaultConfigId)).thenReturn(Optional.of(sampleConfig));

        PortalSupportConfigResponse response = service.getSupportConfig();

        assertNotNull(response);
        assertEquals("0909111222", response.getHotlineNumber());
        assertEquals("Hotline CSKH", response.getHotlineLabel());
        assertEquals("https://zalo.me/0909111222", response.getZaloUrl());
        verify(repository, times(1)).findById(defaultConfigId);
    }

    @Test
    void updateSupportConfig_updatesAndReturnsNewConfig() {
        when(repository.findById(defaultConfigId)).thenReturn(Optional.of(sampleConfig));
        when(repository.save(any(PortalSupportConfig.class))).thenAnswer(invocation -> invocation.getArgument(0));

        UpdatePortalSupportConfigRequest request = UpdatePortalSupportConfigRequest.builder()
                .hotlineNumber("0903999888")
                .hotlineLabel("Hotline Kỹ Sư Trực")
                .zaloUrl("https://zalo.me/0903999888")
                .zaloLabel("Zalo Hỗ Trợ 24/7")
                .workingHours("24/7")
                .workshopAddress("Chi nhánh 2")
                .build();

        UUID adminId = UUID.randomUUID();
        PortalSupportConfigResponse response = service.updateSupportConfig(request, adminId);

        assertNotNull(response);
        assertEquals("0903999888", response.getHotlineNumber());
        assertEquals("Hotline Kỹ Sư Trực", response.getHotlineLabel());
        assertEquals("https://zalo.me/0903999888", response.getZaloUrl());
        verify(repository, times(1)).save(any(PortalSupportConfig.class));
    }
}
