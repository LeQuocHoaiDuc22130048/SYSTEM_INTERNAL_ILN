package com.suachuabientan.system_internal.modules.banner.service;

import com.suachuabientan.system_internal.modules.banner.dto.AppBannerDto;
import com.suachuabientan.system_internal.modules.banner.dto.CreateAppBannerDto;
import com.suachuabientan.system_internal.modules.banner.dto.UpdateAppBannerDto;
import com.suachuabientan.system_internal.modules.banner.entity.AppBanner;
import com.suachuabientan.system_internal.modules.banner.repository.AppBannerRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AppBannerServiceTest {

    @Mock
    private AppBannerRepository bannerRepository;

    private AppBannerService bannerService;

    @BeforeEach
    void setUp() {
        bannerService = new AppBannerService(bannerRepository);
    }

    @Test
    void testGetActiveBanners_FiltersExpiredAndInactive() {
        Instant now = Instant.now();
        UUID id1 = UUID.randomUUID();
        AppBanner activeBanner = AppBanner.builder()
                .title("Banner 1")
                .isActive(true)
                .displayOrder(1)
                .build();
        activeBanner.setId(id1);

        AppBanner futureBanner = AppBanner.builder()
                .title("Future Banner")
                .isActive(true)
                .startDate(now.plus(2, ChronoUnit.DAYS))
                .build();
        futureBanner.setId(UUID.randomUUID());

        AppBanner expiredBanner = AppBanner.builder()
                .title("Expired Banner")
                .isActive(true)
                .endDate(now.minus(1, ChronoUnit.DAYS))
                .build();
        expiredBanner.setId(UUID.randomUUID());

        when(bannerRepository.findAllActive()).thenReturn(List.of(activeBanner, futureBanner, expiredBanner));

        List<AppBannerDto> result = bannerService.getActiveBanners();

        assertEquals(1, result.size());
        assertEquals("Banner 1", result.get(0).getTitle());
    }

    @Test
    void testCreateBanner_SavesSuccessfully() {
        CreateAppBannerDto dto = CreateAppBannerDto.builder()
                .title("Bảo Trì Inverter")
                .badgeText("ƯU ĐÃI")
                .subtitle("Giảm 25%")
                .buttonText("Đặt lịch ngay")
                .actionType("BOOKING")
                .actionValue("Gói ưu đãi")
                .gradientColors("#2563EB,#4F46E5,#1D4ED8")
                .displayOrder(1)
                .isActive(true)
                .build();

        UUID generatedId = UUID.randomUUID();
        when(bannerRepository.save(any(AppBanner.class))).thenAnswer(invocation -> {
            AppBanner saved = invocation.getArgument(0);
            saved.setId(generatedId);
            return saved;
        });

        UUID userId = UUID.randomUUID();
        AppBannerDto result = bannerService.createBanner(dto, null, userId);

        assertNotNull(result);
        assertEquals(generatedId, result.getId());
        assertEquals("Bảo Trì Inverter", result.getTitle());
        assertEquals("ƯU ĐÃI", result.getBadgeText());
        assertEquals("BOTTOM_LEFT", result.getButtonPosition());
        verify(bannerRepository, times(1)).save(any(AppBanner.class));
    }

    @Test
    void testCreateBanner_WithMultipleButtonsAndPositionAndBgImage() {
        var btn1 = com.suachuabientan.system_internal.modules.banner.dto.BannerButtonDto.builder()
                .text("Đặt lịch")
                .actionType("BOOKING")
                .actionValue("Gói VIP")
                .styleType("PRIMARY")
                .build();
        var btn2 = com.suachuabientan.system_internal.modules.banner.dto.BannerButtonDto.builder()
                .text("Hotline")
                .actionType("CALL")
                .actionValue("0987654321")
                .styleType("SECONDARY")
                .build();

        CreateAppBannerDto dto = CreateAppBannerDto.builder()
                .title("Banner Đa Nút")
                .buttonPosition("BOTTOM_RIGHT")
                .buttons(List.of(btn1, btn2))
                .backgroundImageUrl("/api/v1/banners/images/custom_bg.png")
                .build();

        UUID generatedId = UUID.randomUUID();
        when(bannerRepository.save(any(AppBanner.class))).thenAnswer(invocation -> {
            AppBanner saved = invocation.getArgument(0);
            saved.setId(generatedId);
            return saved;
        });

        AppBannerDto result = bannerService.createBanner(dto, null, UUID.randomUUID());

        assertNotNull(result);
        assertEquals("BOTTOM_RIGHT", result.getButtonPosition());
        assertEquals(2, result.getButtons().size());
        assertEquals("Đặt lịch", result.getButtons().get(0).getText());
        assertEquals("Hotline", result.getButtons().get(1).getText());
        assertEquals("/api/v1/banners/images/custom_bg.png", result.getBackgroundImageUrl());
    }

    @Test
    void testToggleActive_InvertsStatus() {
        UUID id = UUID.randomUUID();
        AppBanner banner = AppBanner.builder()
                .title("Banner Toggle")
                .isActive(true)
                .build();
        banner.setId(id);
        banner.setIsDeleted(false);

        when(bannerRepository.findById(id)).thenReturn(Optional.of(banner));
        when(bannerRepository.save(any(AppBanner.class))).thenAnswer(invocation -> invocation.getArgument(0));

        AppBannerDto toggled = bannerService.toggleActive(id, UUID.randomUUID());

        assertFalse(toggled.getIsActive());
        verify(bannerRepository).save(banner);
    }

    @Test
    void testDeleteBanner_SoftDeletes() {
        UUID id = UUID.randomUUID();
        AppBanner banner = AppBanner.builder()
                .title("Banner Delete")
                .isActive(true)
                .build();
        banner.setId(id);
        banner.setIsDeleted(false);

        when(bannerRepository.findById(id)).thenReturn(Optional.of(banner));

        UUID userId = UUID.randomUUID();
        bannerService.deleteBanner(id, userId);

        assertTrue(banner.getIsDeleted());
        assertNotNull(banner.getDeletedAt());
        assertEquals(userId, banner.getUpdatedBy());
        verify(bannerRepository).save(banner);
    }
}
