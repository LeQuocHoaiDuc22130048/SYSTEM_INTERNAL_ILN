package com.suachuabientan.system_internal.modules.banner.service;

import com.suachuabientan.system_internal.modules.banner.dto.AppBannerDto;
import com.suachuabientan.system_internal.modules.banner.dto.CreateAppBannerDto;
import com.suachuabientan.system_internal.modules.banner.dto.UpdateAppBannerDto;
import com.suachuabientan.system_internal.modules.banner.dto.BannerButtonDto;
import com.suachuabientan.system_internal.modules.banner.dto.UpdateAppBannerDto;
import com.suachuabientan.system_internal.modules.banner.dto.BannerButtonDto;
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
    void canvasDesignPersistsThroughCreateUpdateAndResponse() {
        String design = "{\"version\":1,\"nodes\":{\"title\":{\"x\":5,\"y\":10,\"width\":90,\"height\":30,\"fontSize\":24,\"color\":\"#facc15\"}}}";
        when(bannerRepository.save(any(AppBanner.class))).thenAnswer(call -> call.getArgument(0));
        AppBannerDto created = bannerService.createBanner(CreateAppBannerDto.builder()
                .title("Canvas").designJson(design).build(), null, null, UUID.randomUUID());
        assertEquals(design, created.getDesignJson());
        UUID id = UUID.randomUUID();
        AppBanner existing = AppBanner.builder().title("Canvas").designJson(design).build();
        existing.setId(id);
        when(bannerRepository.findById(id)).thenReturn(Optional.of(existing));
        AppBannerDto updated = bannerService.updateBanner(id,
                UpdateAppBannerDto.builder().title("New title").build(), null, null, UUID.randomUUID());
        assertEquals(design, updated.getDesignJson());
    }

    @Test
    void invalidCanvasIsRejectedBeforeSaving() {
        for (String json : List.of("{", "{\"version\":2,\"nodes\":{}}",
                "{\"version\":1,\"nodes\":{\"title\":{\"x\":95,\"y\":0,\"width\":20,\"height\":20}}}")) {
            assertThrows(com.suachuabientan.system_internal.common.exception.BusinessException.class,
                () -> bannerService.createBanner(CreateAppBannerDto.builder().title("Invalid")
                        .designJson(json).build(), null, null, UUID.randomUUID()));
        }
        verify(bannerRepository, never()).save(any());
    }

    @Test
    void bannerActionRemainsIndependentOfCtaAndEmptyButtons() {
        UUID id = UUID.randomUUID();
        AppBanner banner = AppBanner.builder().title("Banner").build();
        banner.setId(id);
        when(bannerRepository.findById(id)).thenReturn(Optional.of(banner));
        when(bannerRepository.save(any(AppBanner.class))).thenAnswer(call -> call.getArgument(0));
        UpdateAppBannerDto dto = UpdateAppBannerDto.builder().title("Banner")
                .actionType("SCREEN").actionValue("repair_orders")
                .buttons(List.of(BannerButtonDto.builder().text("Kho")
                        .actionType("SCREEN").actionValue("warehouse").styleType("PRIMARY").build()))
                .build();
        bannerService.updateBanner(id, dto, null, null, UUID.randomUUID());
        assertEquals("SCREEN", banner.getActionType());
        assertEquals("repair_orders", banner.getActionValue());
        assertTrue(banner.getButtonsJson().contains("warehouse"));
        dto.setButtons(List.of());
        bannerService.updateBanner(id, dto, null, null, UUID.randomUUID());
        assertEquals("repair_orders", banner.getActionValue());
        assertEquals("[]", banner.getButtonsJson());
    }

    @Test
    void explicitEmptyImagesClearExistingBackgroundAndMascot() {
        UUID id = UUID.randomUUID();
        AppBanner banner = AppBanner.builder().title("Banner")
                .backgroundImageUrl("/old-bg.png").imageUrl("/old-mascot.png").build();
        banner.setId(id);
        when(bannerRepository.findById(id)).thenReturn(Optional.of(banner));
        when(bannerRepository.save(any(AppBanner.class))).thenAnswer(call -> call.getArgument(0));
        UpdateAppBannerDto dto = UpdateAppBannerDto.builder()
                .title("Banner").backgroundImageUrl("").imageUrl("").build();
        bannerService.updateBanner(id, dto, null, null, UUID.randomUUID());
        assertEquals("", banner.getBackgroundImageUrl());
        assertEquals("", banner.getImageUrl());
    }

    @Test
    void omittedImageFieldsPreserveExistingImages() {
        UUID id = UUID.randomUUID();
        AppBanner banner = AppBanner.builder().title("Banner")
                .backgroundImageUrl("/old-bg.png").imageUrl("/old-mascot.png").build();
        banner.setId(id);
        when(bannerRepository.findById(id)).thenReturn(Optional.of(banner));
        when(bannerRepository.save(any(AppBanner.class))).thenAnswer(call -> call.getArgument(0));
        bannerService.updateBanner(id, UpdateAppBannerDto.builder().title("Updated").build(),
                null, null, UUID.randomUUID());
        assertEquals("/old-bg.png", banner.getBackgroundImageUrl());
        assertEquals("/old-mascot.png", banner.getImageUrl());
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
    void testCreateBanner_WithCustomButtonCoordinates() {
        CreateAppBannerDto dto = CreateAppBannerDto.builder()
                .title("Banner Tùy Biến Tọa Độ")
                .buttonPosition("CUSTOM")
                .buttonTop(18.5)
                .buttonLeft(24.0)
                .buttonBottom(10.0)
                .buttonRight(12.0)
                .build();

        UUID generatedId = UUID.randomUUID();
        when(bannerRepository.save(any(AppBanner.class))).thenAnswer(invocation -> {
            AppBanner saved = invocation.getArgument(0);
            saved.setId(generatedId);
            return saved;
        });

        AppBannerDto result = bannerService.createBanner(dto, null, UUID.randomUUID());

        assertNotNull(result);
        assertEquals("CUSTOM", result.getButtonPosition());
        assertEquals(18.5, result.getButtonTop());
        assertEquals(24.0, result.getButtonLeft());
        assertEquals(10.0, result.getButtonBottom());
        assertEquals(12.0, result.getButtonRight());
    }

    @Test
    void testCreateBanner_WithZeroButtons() {
        CreateAppBannerDto dto = CreateAppBannerDto.builder()
                .title("Banner Không Nút Bấm")
                .buttons(List.of())
                .build();

        UUID generatedId = UUID.randomUUID();
        when(bannerRepository.save(any(AppBanner.class))).thenAnswer(invocation -> {
            AppBanner saved = invocation.getArgument(0);
            saved.setId(generatedId);
            return saved;
        });

        AppBannerDto result = bannerService.createBanner(dto, null, UUID.randomUUID());

        assertNotNull(result);
        assertTrue(result.getButtons().isEmpty());
        assertNull(result.getButtonText());
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

    @Test
    void testCreateBanner_WithFontFamily() {
        CreateAppBannerDto dto = CreateAppBannerDto.builder()
                .title("Banner Font Tùy Chỉnh")
                .fontFamily("Montserrat")
                .build();

        UUID generatedId = UUID.randomUUID();
        when(bannerRepository.save(any(AppBanner.class))).thenAnswer(invocation -> {
            AppBanner saved = invocation.getArgument(0);
            saved.setId(generatedId);
            return saved;
        });

        AppBannerDto result = bannerService.createBanner(dto, null, UUID.randomUUID());

        assertNotNull(result);
        assertEquals("Montserrat", result.getFontFamily());
    }

    @Test
    void testCreateBanner_WithEmptyTitleAndNoMascot() {
        CreateAppBannerDto dto = CreateAppBannerDto.builder()
                .title(null)
                .badgeText("")
                .subtitle("")
                .imagePosition("NONE")
                .backgroundImageUrl("/api/v1/banners/images/uploaded_banner.jpg")
                .build();

        UUID generatedId = UUID.randomUUID();
        when(bannerRepository.save(any(AppBanner.class))).thenAnswer(invocation -> {
            AppBanner saved = invocation.getArgument(0);
            saved.setId(generatedId);
            return saved;
        });

        AppBannerDto result = bannerService.createBanner(dto, null, UUID.randomUUID());

        assertNotNull(result);
        assertEquals("", result.getTitle());
        assertEquals("NONE", result.getImagePosition());
        assertNull(result.getImageUrl());
        assertEquals("/api/v1/banners/images/uploaded_banner.jpg", result.getBackgroundImageUrl());
        assertFalse(result.getDarkenOverlay());
    }

    @Test
    void testCreateBanner_WithCustomBackgroundAndDarkenOverlay() {
        CreateAppBannerDto dto = CreateAppBannerDto.builder()
                .title("Ưu Đãi Đặc Biệt")
                .backgroundImageUrl("/api/v1/banners/images/bg_texture.jpg")
                .darkenOverlay(true)
                .build();

        UUID generatedId = UUID.randomUUID();
        when(bannerRepository.save(any(AppBanner.class))).thenAnswer(invocation -> {
            AppBanner saved = invocation.getArgument(0);
            saved.setId(generatedId);
            return saved;
        });

        AppBannerDto result = bannerService.createBanner(dto, null, UUID.randomUUID());

        assertNotNull(result);
        assertEquals("Ưu Đãi Đặc Biệt", result.getTitle());
        assertTrue(result.getDarkenOverlay());
    }
}
