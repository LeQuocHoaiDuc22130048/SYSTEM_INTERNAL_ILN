package com.suachuabientan.system_internal.modules.banner.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.banner.dto.AppBannerDto;
import com.suachuabientan.system_internal.modules.banner.dto.CreateAppBannerDto;
import com.suachuabientan.system_internal.modules.banner.dto.ReorderBannersDto;
import com.suachuabientan.system_internal.modules.banner.dto.UpdateAppBannerDto;
import com.suachuabientan.system_internal.modules.banner.service.AppBannerService;
import com.suachuabientan.system_internal.security.authorization.RoleExpressions;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

@Tag(name = "App Banners", description = "Quản lý banner quảng cáo và ưu đãi cho ứng dụng di động")
@RestController
@RequestMapping("/api/v1/banners")
@RequiredArgsConstructor
public class AppBannerController {

    private final AppBannerService bannerService;

    @Operation(summary = "Lấy danh sách banner đang hoạt động cho ứng dụng di động")
    @GetMapping
    public ResponseEntity<ApiResponse<List<AppBannerDto>>> getActiveBanners() {
        return ResponseEntity.ok(ApiResponse.success(bannerService.getActiveBanners()));
    }

    @Operation(summary = "Lấy danh sách banner đang hoạt động (alias)")
    @GetMapping("/active")
    public ResponseEntity<ApiResponse<List<AppBannerDto>>> getActiveBannersAlias() {
        return ResponseEntity.ok(ApiResponse.success(bannerService.getActiveBanners()));
    }

    @Operation(summary = "Lấy tất cả banner cho trang quản trị website")
    @PreAuthorize(RoleExpressions.MANAGER_OR_ABOVE)
    @GetMapping("/all")
    public ResponseEntity<ApiResponse<List<AppBannerDto>>> getAllBanners() {
        return ResponseEntity.ok(ApiResponse.success(bannerService.getAllBanners()));
    }

    @Operation(summary = "Lấy chi tiết 1 banner theo ID")
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<AppBannerDto>> getBannerById(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(bannerService.getBannerById(id)));
    }

    @Operation(summary = "Tạo mới banner (JSON)")
    @PreAuthorize(RoleExpressions.MANAGER_OR_ABOVE)
    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<ApiResponse<AppBannerDto>> createBannerJson(
            @RequestBody @Valid CreateAppBannerDto dto,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        UUID userId = userDetails != null ? userDetails.getUserId() : null;
        AppBannerDto created = bannerService.createBanner(dto, null, userId);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(created));
    }

    @Operation(summary = "Tạo mới banner kèm file ảnh (Multipart)")
    @PreAuthorize(RoleExpressions.MANAGER_OR_ABOVE)
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<AppBannerDto>> createBannerMultipart(
            @RequestParam("title") String title,
            @RequestParam(value = "badgeText", required = false) String badgeText,
            @RequestParam(value = "subtitle", required = false) String subtitle,
            @RequestParam(value = "buttonText", required = false) String buttonText,
            @RequestParam(value = "actionType", required = false, defaultValue = "BOOKING") String actionType,
            @RequestParam(value = "actionValue", required = false) String actionValue,
            @RequestParam(value = "buttonPosition", required = false, defaultValue = "BOTTOM_LEFT") String buttonPosition,
            @RequestParam(value = "buttonTop", required = false) Double buttonTop,
            @RequestParam(value = "buttonBottom", required = false) Double buttonBottom,
            @RequestParam(value = "buttonLeft", required = false) Double buttonLeft,
            @RequestParam(value = "buttonRight", required = false) Double buttonRight,
            @RequestParam(value = "buttonsJson", required = false) String buttonsJson,
            @RequestParam(value = "imageUrl", required = false) String imageUrl,
            @RequestParam(value = "imagePosition", required = false, defaultValue = "RIGHT") String imagePosition,
            @RequestParam(value = "fontFamily", required = false, defaultValue = "Be Vietnam Pro") String fontFamily,
            @RequestParam(value = "backgroundImageUrl", required = false) String backgroundImageUrl,
            @RequestParam(value = "darkenOverlay", required = false) Boolean darkenOverlay,
            @RequestParam(value = "gradientColors", required = false) String gradientColors,
            @RequestParam(value = "displayOrder", required = false, defaultValue = "0") Integer displayOrder,
            @RequestParam(value = "isActive", required = false, defaultValue = "true") Boolean isActive,
            @RequestParam(value = "startDate", required = false) String startDate,
            @RequestParam(value = "endDate", required = false) String endDate,
            @RequestParam(value = "image", required = false) MultipartFile image,
            @RequestParam(value = "bgImage", required = false) MultipartFile bgImage,
            @AuthenticationPrincipal CustomUserDetails userDetails) {

        Instant start = StringUtils.hasText(startDate) ? Instant.parse(startDate) : null;
        Instant end = StringUtils.hasText(endDate) ? Instant.parse(endDate) : null;

        CreateAppBannerDto dto = CreateAppBannerDto.builder()
                .title(title)
                .badgeText(badgeText)
                .subtitle(subtitle)
                .buttonText(buttonText)
                .actionType(actionType)
                .actionValue(actionValue)
                .buttonPosition(buttonPosition)
                .buttonTop(buttonTop)
                .buttonBottom(buttonBottom)
                .buttonLeft(buttonLeft)
                .buttonRight(buttonRight)
                .buttonsJson(buttonsJson)
                .imageUrl(imageUrl)
                .imagePosition(imagePosition)
                .fontFamily(fontFamily)
                .backgroundImageUrl(backgroundImageUrl)
                .darkenOverlay(darkenOverlay)
                .gradientColors(gradientColors)
                .displayOrder(displayOrder)
                .isActive(isActive)
                .startDate(start)
                .endDate(end)
                .build();

        UUID userId = userDetails != null ? userDetails.getUserId() : null;
        AppBannerDto created = bannerService.createBanner(dto, image, bgImage, userId);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(created));
    }

    @Operation(summary = "Cập nhật banner (JSON)")
    @PreAuthorize(RoleExpressions.MANAGER_OR_ABOVE)
    @PutMapping(value = "/{id}", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<ApiResponse<AppBannerDto>> updateBannerJson(
            @PathVariable UUID id,
            @RequestBody @Valid UpdateAppBannerDto dto,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        UUID userId = userDetails != null ? userDetails.getUserId() : null;
        AppBannerDto updated = bannerService.updateBanner(id, dto, null, null, userId);
        return ResponseEntity.ok(ApiResponse.success(updated, "Cập nhật banner thành công"));
    }

    @Operation(summary = "Cập nhật banner kèm file ảnh (Multipart)")
    @PreAuthorize(RoleExpressions.MANAGER_OR_ABOVE)
    @PutMapping(value = "/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<AppBannerDto>> updateBannerMultipart(
            @PathVariable UUID id,
            @RequestParam("title") String title,
            @RequestParam(value = "badgeText", required = false) String badgeText,
            @RequestParam(value = "subtitle", required = false) String subtitle,
            @RequestParam(value = "buttonText", required = false) String buttonText,
            @RequestParam(value = "actionType", required = false) String actionType,
            @RequestParam(value = "actionValue", required = false) String actionValue,
            @RequestParam(value = "buttonPosition", required = false) String buttonPosition,
            @RequestParam(value = "buttonTop", required = false) Double buttonTop,
            @RequestParam(value = "buttonBottom", required = false) Double buttonBottom,
            @RequestParam(value = "buttonLeft", required = false) Double buttonLeft,
            @RequestParam(value = "buttonRight", required = false) Double buttonRight,
            @RequestParam(value = "buttonsJson", required = false) String buttonsJson,
            @RequestParam(value = "imageUrl", required = false) String imageUrl,
            @RequestParam(value = "imagePosition", required = false) String imagePosition,
            @RequestParam(value = "fontFamily", required = false) String fontFamily,
            @RequestParam(value = "backgroundImageUrl", required = false) String backgroundImageUrl,
            @RequestParam(value = "darkenOverlay", required = false) Boolean darkenOverlay,
            @RequestParam(value = "gradientColors", required = false) String gradientColors,
            @RequestParam(value = "displayOrder", required = false) Integer displayOrder,
            @RequestParam(value = "isActive", required = false) Boolean isActive,
            @RequestParam(value = "startDate", required = false) String startDate,
            @RequestParam(value = "endDate", required = false) String endDate,
            @RequestParam(value = "image", required = false) MultipartFile image,
            @RequestParam(value = "bgImage", required = false) MultipartFile bgImage,
            @AuthenticationPrincipal CustomUserDetails userDetails) {

        Instant start = StringUtils.hasText(startDate) ? Instant.parse(startDate) : null;
        Instant end = StringUtils.hasText(endDate) ? Instant.parse(endDate) : null;

        UpdateAppBannerDto dto = UpdateAppBannerDto.builder()
                .title(title)
                .badgeText(badgeText)
                .subtitle(subtitle)
                .buttonText(buttonText)
                .actionType(actionType)
                .actionValue(actionValue)
                .buttonPosition(buttonPosition)
                .buttonTop(buttonTop)
                .buttonBottom(buttonBottom)
                .buttonLeft(buttonLeft)
                .buttonRight(buttonRight)
                .buttonsJson(buttonsJson)
                .imageUrl(imageUrl)
                .imagePosition(imagePosition)
                .fontFamily(fontFamily)
                .backgroundImageUrl(backgroundImageUrl)
                .darkenOverlay(darkenOverlay)
                .gradientColors(gradientColors)
                .displayOrder(displayOrder)
                .isActive(isActive)
                .startDate(start)
                .endDate(end)
                .build();

        UUID userId = userDetails != null ? userDetails.getUserId() : null;
        AppBannerDto updated = bannerService.updateBanner(id, dto, image, bgImage, userId);
        return ResponseEntity.ok(ApiResponse.success(updated, "Cập nhật banner thành công"));
    }

    @Operation(summary = "Bật/tắt trạng thái hiển thị của banner")
    @PreAuthorize(RoleExpressions.MANAGER_OR_ABOVE)
    @PatchMapping("/{id}/toggle-active")
    public ResponseEntity<ApiResponse<AppBannerDto>> toggleActive(
            @PathVariable UUID id,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        UUID userId = userDetails != null ? userDetails.getUserId() : null;
        AppBannerDto updated = bannerService.toggleActive(id, userId);
        return ResponseEntity.ok(ApiResponse.success(updated, "Đã cập nhật trạng thái hiển thị banner"));
    }

    @Operation(summary = "Sắp xếp lại thứ tự banner")
    @PreAuthorize(RoleExpressions.MANAGER_OR_ABOVE)
    @PatchMapping("/reorder")
    public ResponseEntity<ApiResponse<Void>> reorderBanners(
            @RequestBody @Valid ReorderBannersDto dto,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        UUID userId = userDetails != null ? userDetails.getUserId() : null;
        bannerService.reorder(dto.getBannerIds(), userId);
        return ResponseEntity.ok(ApiResponse.success(null, "Đã cập nhật thứ tự banner"));
    }

    @Operation(summary = "Xóa banner")
    @PreAuthorize(RoleExpressions.MANAGER_OR_ABOVE)
    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteBanner(
            @PathVariable UUID id,
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        UUID userId = userDetails != null ? userDetails.getUserId() : null;
        bannerService.deleteBanner(id, userId);
        return ResponseEntity.ok(ApiResponse.success(null, "Đã xóa banner"));
    }

    @Operation(summary = "Tải file hình ảnh của banner")
    @GetMapping("/images/{filename:.+}")
    public ResponseEntity<Resource> getBannerImage(@PathVariable String filename) {
        Resource resource = bannerService.getImageResource(filename);
        MediaType mediaType = MediaType.APPLICATION_OCTET_STREAM;
        try {
            String probe = Files.probeContentType(resource.getFile().toPath());
            if (probe != null) {
                mediaType = MediaType.parseMediaType(probe);
            }
        } catch (IOException ignored) {
            if (filename.toLowerCase().endsWith(".png")) mediaType = MediaType.IMAGE_PNG;
            else if (filename.toLowerCase().endsWith(".jpg") || filename.toLowerCase().endsWith(".jpeg")) mediaType = MediaType.IMAGE_JPEG;
            else if (filename.toLowerCase().endsWith(".webp")) mediaType = MediaType.parseMediaType("image/webp");
            else if (filename.toLowerCase().endsWith(".svg")) mediaType = MediaType.parseMediaType("image/svg+xml");
        }

        return ResponseEntity.ok()
                .contentType(mediaType)
                .cacheControl(CacheControl.maxAge(30, TimeUnit.DAYS).cachePublic())
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + filename + "\"")
                .body(resource);
    }
}
