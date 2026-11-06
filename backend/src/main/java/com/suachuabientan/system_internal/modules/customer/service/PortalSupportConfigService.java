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
                ? request.getHotlineLabel().trim() : "Liên hệ kỹ thuật");
        config.setZaloUrl(request.getZaloUrl() != null ? request.getZaloUrl().trim() : "");
        config.setZaloLabel(request.getZaloLabel() != null && !request.getZaloLabel().isBlank()
                ? request.getZaloLabel().trim() : "");
        if (request.getWorkingHours() != null) {
            config.setWorkingHours(request.getWorkingHours().trim());
        }
        if (request.getWorkshopAddress() != null) {
            config.setWorkshopAddress(request.getWorkshopAddress().trim());
        }
        if (request.getMapUrl() != null) {
            config.setMapUrl(request.getMapUrl().trim());
        }
        if (request.getLatitude() != null) {
            config.setLatitude(request.getLatitude());
        }
        if (request.getLongitude() != null) {
            config.setLongitude(request.getLongitude());
        }
        if (request.getMapImageUrl() != null) {
            config.setMapImageUrl(request.getMapImageUrl().trim());
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
                .hotlineNumber("0964 266 771")
                .hotlineLabel("Liên hệ kỹ thuật")
                .zaloUrl("")
                .zaloLabel("")
                .workingHours("08:00 - 17:30 (Thứ 2 - Thứ 7)")
                .workshopAddress("243 Quốc Lộ 1A, Khu phố 4, Phường Tam Bình, TP. Hồ Chí Minh, Việt Nam")
                .mapUrl("https://www.google.com/maps/search/?api=1&query=243+Quốc+Lộ+1A,+Tam+Bình,+TP+Hồ+Chí+Minh")
                .latitude(10.854611)
                .longitude(106.703212)
                .mapImageUrl("")
                .updatedAt(LocalDateTime.now())
                .build();
        return repository.save(defaultConfig);
    }

    private PortalSupportConfigResponse mapToResponse(PortalSupportConfig entity) {
        String phone = entity.getHotlineNumber();
        if (phone == null || phone.isBlank() || "0909000000".equals(phone.replaceAll("\\s+", ""))) {
            phone = "0964 266 771";
        }
        String label = entity.getHotlineLabel();
        if (label == null || label.isBlank() || "Hotline Kỹ Thuật".equalsIgnoreCase(label.trim())) {
            label = "Liên hệ kỹ thuật";
        }
        String address = entity.getWorkshopAddress();
        if (address == null || address.isBlank() || "Trung tâm kỹ thuật sửa chữa thiết bị công nghiệp".equalsIgnoreCase(address.trim())) {
            address = "243 Quốc Lộ 1A, Khu phố 4, Phường Tam Bình, TP. Hồ Chí Minh, Việt Nam";
        }
        String mapUrl = entity.getMapUrl();
        if (mapUrl == null || mapUrl.isBlank()) {
            mapUrl = "https://www.google.com/maps/search/?api=1&query=243+Quốc+Lộ+1A,+Tam+Bình,+TP+Hồ+Chí+Minh";
        }
        Double lat = entity.getLatitude() != null ? entity.getLatitude() : 10.854611;
        Double lng = entity.getLongitude() != null ? entity.getLongitude() : 106.703212;

        return PortalSupportConfigResponse.builder()
                .hotlineNumber(phone)
                .hotlineLabel(label)
                .zaloUrl(entity.getZaloUrl())
                .zaloLabel(entity.getZaloLabel())
                .workingHours(entity.getWorkingHours())
                .workshopAddress(address)
                .mapUrl(mapUrl)
                .latitude(lat)
                .longitude(lng)
                .mapImageUrl(entity.getMapImageUrl())
                .updatedAt(entity.getUpdatedAt())
                .build();
    }
}
