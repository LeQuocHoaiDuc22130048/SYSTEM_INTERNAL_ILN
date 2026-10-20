package com.suachuabientan.system_internal.modules.customer.service;

import com.suachuabientan.system_internal.modules.customer.dto.PortalSupportConfigResponse;
import com.suachuabientan.system_internal.modules.customer.dto.UpdatePortalSupportConfigRequest;
import com.suachuabientan.system_internal.modules.customer.entity.PortalSupportConfig;
import com.suachuabientan.system_internal.modules.customer.repository.PortalSupportConfigRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class PortalSupportConfigService {

    private static final UUID DEFAULT_CONFIG_ID = UUID.fromString("00000000-0000-0000-0000-000000000001");
    private final PortalSupportConfigRepository repository;

    @Transactional(readOnly = true)
    public PortalSupportConfigResponse getSupportConfig() {
        PortalSupportConfig config = repository.findById(DEFAULT_CONFIG_ID)
                .orElseGet(this::createDefaultConfig);
        return mapToResponse(config);
    }

    @Transactional
    public PortalSupportConfigResponse updateSupportConfig(UpdatePortalSupportConfigRequest request, UUID adminUserId) {
        PortalSupportConfig config = repository.findById(DEFAULT_CONFIG_ID)
                .orElseGet(this::createDefaultConfig);

        config.setHotlineNumber(request.getHotlineNumber().trim());
        config.setHotlineLabel(request.getHotlineLabel() != null && !request.getHotlineLabel().isBlank()
                ? request.getHotlineLabel().trim() : "Hotline Kỹ Thuật");
        config.setZaloUrl(request.getZaloUrl().trim());
        config.setZaloLabel(request.getZaloLabel() != null && !request.getZaloLabel().isBlank()
                ? request.getZaloLabel().trim() : "Chat Zalo Tiếp Nhận");
        if (request.getWorkingHours() != null) {
            config.setWorkingHours(request.getWorkingHours().trim());
        }
        if (request.getWorkshopAddress() != null) {
            config.setWorkshopAddress(request.getWorkshopAddress().trim());
        }
        config.setUpdatedAt(LocalDateTime.now());
        config.setUpdatedBy(adminUserId);

        PortalSupportConfig saved = repository.save(config);
        log.info("Cập nhật kênh hỗ trợ khách hàng thành công bởi admin: {}", adminUserId);
        return mapToResponse(saved);
    }

    private PortalSupportConfig createDefaultConfig() {
        PortalSupportConfig defaultConfig = PortalSupportConfig.builder()
                .id(DEFAULT_CONFIG_ID)
                .hotlineNumber("0909000000")
                .hotlineLabel("Hotline Kỹ Thuật")
                .zaloUrl("https://zalo.me")
                .zaloLabel("Chat Zalo Tiếp Nhận")
                .workingHours("08:00 - 17:30 (Thứ 2 - Thứ 7)")
                .workshopAddress("Trung tâm kỹ thuật sửa chữa thiết bị công nghiệp")
                .updatedAt(LocalDateTime.now())
                .build();
        return repository.save(defaultConfig);
    }

    private PortalSupportConfigResponse mapToResponse(PortalSupportConfig entity) {
        return PortalSupportConfigResponse.builder()
                .hotlineNumber(entity.getHotlineNumber())
                .hotlineLabel(entity.getHotlineLabel())
                .zaloUrl(entity.getZaloUrl())
                .zaloLabel(entity.getZaloLabel())
                .workingHours(entity.getWorkingHours())
                .workshopAddress(entity.getWorkshopAddress())
                .updatedAt(entity.getUpdatedAt())
                .build();
    }
}
