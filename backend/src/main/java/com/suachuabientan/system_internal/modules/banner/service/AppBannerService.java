package com.suachuabientan.system_internal.modules.banner.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.banner.dto.AppBannerDto;
import com.suachuabientan.system_internal.modules.banner.dto.CreateAppBannerDto;
import com.suachuabientan.system_internal.modules.banner.dto.UpdateAppBannerDto;
import com.suachuabientan.system_internal.modules.banner.entity.AppBanner;
import com.suachuabientan.system_internal.modules.banner.repository.AppBannerRepository;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.suachuabientan.system_internal.modules.banner.dto.BannerButtonDto;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.net.MalformedURLException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AppBannerService {

    private static final Logger log = LoggerFactory.getLogger(AppBannerService.class);

    private final AppBannerRepository bannerRepository;

    @Value("${app.banner.upload-dir:./uploads/banners}")
    private String bannerUploadDir;

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Transactional(readOnly = true)
    public List<AppBannerDto> getActiveBanners() {
        Instant now = Instant.now();
        return bannerRepository.findAllActive().stream()
                .filter(b -> (b.getStartDate() == null || !now.isBefore(b.getStartDate())))
                .filter(b -> (b.getEndDate() == null || !now.isAfter(b.getEndDate())))
                .map(AppBannerDto::fromEntity)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<AppBannerDto> getAllBanners() {
        return bannerRepository.findAllNonDeleted().stream()
                .map(AppBannerDto::fromEntity)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public AppBannerDto getBannerById(UUID id) {
        AppBanner banner = bannerRepository.findById(id)
                .filter(b -> !Boolean.TRUE.equals(b.getIsDeleted()))
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy banner với ID: " + id));
        return AppBannerDto.fromEntity(banner);
    }

    @Transactional
    public AppBannerDto createBanner(CreateAppBannerDto dto, MultipartFile imageFile, UUID currentUserId) {
        return createBanner(dto, imageFile, null, currentUserId);
    }

    @Transactional
    public AppBannerDto createBanner(CreateAppBannerDto dto, MultipartFile imageFile, MultipartFile bgImageFile, UUID currentUserId) {
        String finalImageUrl = dto.getImageUrl();
        if (imageFile != null && !imageFile.isEmpty()) {
            finalImageUrl = saveImageFile(imageFile);
        }

        String finalBgImageUrl = dto.getBackgroundImageUrl();
        if (bgImageFile != null && !bgImageFile.isEmpty()) {
            finalBgImageUrl = saveImageFile(bgImageFile);
        }

        AppBanner banner = AppBanner.builder()
                .title(dto.getTitle() != null ? dto.getTitle().trim() : "")
                .badgeText(dto.getBadgeText())
                .subtitle(dto.getSubtitle())
                .buttonText(dto.getButtonText())
                .actionType(StringUtils.hasText(dto.getActionType()) ? dto.getActionType() : "BOOKING")
                .actionValue(dto.getActionValue())
                .buttonPosition(StringUtils.hasText(dto.getButtonPosition()) ? dto.getButtonPosition() : "BOTTOM_LEFT")
                .imageUrl(finalImageUrl)
                .imagePosition(StringUtils.hasText(dto.getImagePosition()) ? dto.getImagePosition() : "RIGHT")
                .fontFamily(StringUtils.hasText(dto.getFontFamily()) ? dto.getFontFamily() : "Be Vietnam Pro")
                .designJson(validateDesign(dto.getDesignJson()))
                .backgroundImageUrl(finalBgImageUrl)
                .darkenOverlay(dto.getDarkenOverlay() != null ? dto.getDarkenOverlay() : false)
                .gradientColors(StringUtils.hasText(dto.getGradientColors()) ? dto.getGradientColors() : "#2563EB,#4F46E5,#1D4ED8")
                .displayOrder(dto.getDisplayOrder() != null ? dto.getDisplayOrder() : 0)
                .isActive(dto.getIsActive() != null ? dto.getIsActive() : true)
                .startDate(dto.getStartDate())
                .endDate(dto.getEndDate())
                .build();

        applyButtonsAndPosition(banner, dto.getButtons(), dto.getButtonsJson(), dto.getButtonPosition(),
                dto.getButtonTop(), dto.getButtonBottom(), dto.getButtonLeft(), dto.getButtonRight());

        if (currentUserId != null) {
            banner.setCreatedBy(currentUserId);
            banner.setUpdatedBy(currentUserId);
        }

        AppBanner saved = bannerRepository.save(banner);
        log.info("Đã tạo mới banner: {} (ID: {})", saved.getTitle(), saved.getId());
        return AppBannerDto.fromEntity(saved);
    }

    @Transactional
    public AppBannerDto updateBanner(UUID id, UpdateAppBannerDto dto, MultipartFile imageFile, UUID currentUserId) {
        return updateBanner(id, dto, imageFile, null, currentUserId);
    }

    @Transactional
    public AppBannerDto updateBanner(UUID id, UpdateAppBannerDto dto, MultipartFile imageFile, MultipartFile bgImageFile, UUID currentUserId) {
        AppBanner banner = bannerRepository.findById(id)
                .filter(b -> !Boolean.TRUE.equals(b.getIsDeleted()))
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy banner với ID: " + id));

        String finalImageUrl = dto.getImageUrl();
        if (imageFile != null && !imageFile.isEmpty()) {
            finalImageUrl = saveImageFile(imageFile);
        } else if (finalImageUrl == null) {
            // Keep existing image if not provided and not explicitly set
            finalImageUrl = banner.getImageUrl();
        }

        String finalBgImageUrl = dto.getBackgroundImageUrl();
        if (bgImageFile != null && !bgImageFile.isEmpty()) {
            finalBgImageUrl = saveImageFile(bgImageFile);
        } else if (finalBgImageUrl == null) {
            finalBgImageUrl = banner.getBackgroundImageUrl();
        }

        banner.setTitle(dto.getTitle() != null ? dto.getTitle().trim() : "");
        banner.setBadgeText(dto.getBadgeText());
        banner.setSubtitle(dto.getSubtitle());
        if (dto.getActionType() != null) {
            banner.setActionType(dto.getActionType());
            banner.setActionValue(dto.getActionValue());
        }

        banner.setImageUrl(finalImageUrl);
        if (StringUtils.hasText(dto.getImagePosition())) {
            banner.setImagePosition(dto.getImagePosition());
        }
        if (StringUtils.hasText(dto.getFontFamily())) {
            banner.setFontFamily(dto.getFontFamily());
        }
        if (dto.getDesignJson() != null) banner.setDesignJson(validateDesign(dto.getDesignJson()));
        banner.setBackgroundImageUrl(finalBgImageUrl);
        if (dto.getDarkenOverlay() != null) {
            banner.setDarkenOverlay(dto.getDarkenOverlay());
        }
        if (StringUtils.hasText(dto.getGradientColors())) {
            banner.setGradientColors(dto.getGradientColors());
        }
        if (dto.getDisplayOrder() != null) {
            banner.setDisplayOrder(dto.getDisplayOrder());
        }
        if (dto.getIsActive() != null) {
            banner.setIsActive(dto.getIsActive());
        }
        banner.setStartDate(dto.getStartDate());
        banner.setEndDate(dto.getEndDate());

        applyButtonsAndPosition(banner, dto.getButtons(), dto.getButtonsJson(), dto.getButtonPosition(),
                dto.getButtonTop(), dto.getButtonBottom(), dto.getButtonLeft(), dto.getButtonRight());

        if (currentUserId != null) {
            banner.setUpdatedBy(currentUserId);
        }

        AppBanner saved = bannerRepository.save(banner);
        log.info("Đã cập nhật banner ID: {}", saved.getId());
        return AppBannerDto.fromEntity(saved);
    }

    private String validateDesign(String json) {
        if (!StringUtils.hasText(json)) return null;
        if (json.length() > 20000) throw new BusinessException("Cấu hình canvas quá lớn.");
        try {
            var design = objectMapper.readTree(json);
            var nodes = design.get("nodes");
            if (design.path("version").asInt() != 1 || nodes == null || !nodes.isObject()
                    || nodes.isEmpty() || nodes.size() > 7) {
                throw new BusinessException("Cấu hình canvas không hợp lệ.");
            }
            var entries = nodes.fields();
            while (entries.hasNext()) {
                var entry = entries.next();
                if (!entry.getKey().matches("badge|title|subtitle|mascot|button[0-2]")) {
                    throw new BusinessException("Phần tử canvas không hợp lệ.");
                }
                var node = entry.getValue();
                for (String field : java.util.List.of("x", "y", "width", "height")) {
                    var value = node.get(field);
                    if (value == null || !value.isNumber() || !Double.isFinite(value.asDouble())
                            || value.asDouble() < 0 || value.asDouble() > 100
                            || ((field.equals("width") || field.equals("height")) && value.asDouble() < 5)) {
                        throw new BusinessException("Vị trí và kích thước phải nằm trong phạm vi canvas.");
                    }
                }
                if (node.path("x").asDouble() + node.path("width").asDouble() > 100.001
                        || node.path("y").asDouble() + node.path("height").asDouble() > 100.001) {
                    throw new BusinessException("Phần tử vượt ra ngoài canvas.");
                }
            }
            return json;
        } catch (com.fasterxml.jackson.core.JsonProcessingException exception) {
            throw new BusinessException("Cấu hình canvas phải là JSON hợp lệ.");
        }
    }

    private void applyButtonsAndPosition(AppBanner banner, List<BannerButtonDto> buttons, String buttonsJson,
                                         String buttonPosition, Double buttonTop, Double buttonBottom,
                                         Double buttonLeft, Double buttonRight) {
        if (StringUtils.hasText(buttonPosition)) {
            banner.setButtonPosition(buttonPosition);
        } else if (!StringUtils.hasText(banner.getButtonPosition())) {
            banner.setButtonPosition("BOTTOM_LEFT");
        }

        banner.setButtonTop(buttonTop);
        banner.setButtonBottom(buttonBottom);
        banner.setButtonLeft(buttonLeft);
        banner.setButtonRight(buttonRight);

        if (buttons != null && !buttons.isEmpty()) {
            try {
                banner.setButtonsJson(objectMapper.writeValueAsString(buttons));
            } catch (Exception e) {
                log.warn("Lỗi serialize buttons: {}", e.getMessage());
            }
            BannerButtonDto first = buttons.get(0);
            banner.setButtonText(first.getText());
        } else if (buttons != null && buttons.isEmpty()) {
            // Explicitly empty buttons list
            banner.setButtonsJson("[]");
            banner.setButtonText(null);
        } else if (StringUtils.hasText(buttonsJson)) {
            banner.setButtonsJson(buttonsJson);
            try {
                List<BannerButtonDto> list = objectMapper.readValue(buttonsJson, new TypeReference<List<BannerButtonDto>>() {});
                if (!list.isEmpty()) {
                    BannerButtonDto first = list.get(0);
                    banner.setButtonText(first.getText());
                } else {
                    banner.setButtonText(null);
                }
            } catch (Exception ignored) {}
        } else if (StringUtils.hasText(banner.getButtonText()) && !StringUtils.hasText(banner.getButtonsJson())) {
            try {
                List<BannerButtonDto> defaultBtn = List.of(BannerButtonDto.builder()
                        .text(banner.getButtonText())
                        .actionType(StringUtils.hasText(banner.getActionType()) ? banner.getActionType() : "BOOKING")
                        .actionValue(banner.getActionValue())
                        .styleType("PRIMARY")
                        .build());
                banner.setButtonsJson(objectMapper.writeValueAsString(defaultBtn));
            } catch (Exception ignored) {}
        }
    }

    @Transactional
    public AppBannerDto toggleActive(UUID id, UUID currentUserId) {
        AppBanner banner = bannerRepository.findById(id)
                .filter(b -> !Boolean.TRUE.equals(b.getIsDeleted()))
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy banner với ID: " + id));

        banner.setIsActive(!Boolean.TRUE.equals(banner.getIsActive()));
        if (currentUserId != null) {
            banner.setUpdatedBy(currentUserId);
        }
        AppBanner saved = bannerRepository.save(banner);
        log.info("Đã đổi trạng thái active banner ID {}: {}", id, saved.getIsActive());
        return AppBannerDto.fromEntity(saved);
    }

    @Transactional
    public void reorder(List<UUID> bannerIds, UUID currentUserId) {
        if (bannerIds == null || bannerIds.isEmpty()) return;

        for (int i = 0; i < bannerIds.size(); i++) {
            UUID id = bannerIds.get(i);
            int order = i + 1;
            bannerRepository.findById(id).ifPresent(b -> {
                b.setDisplayOrder(order);
                if (currentUserId != null) {
                    b.setUpdatedBy(currentUserId);
                }
                bannerRepository.save(b);
            });
        }
        log.info("Đã cập nhật thứ tự hiển thị cho {} banner", bannerIds.size());
    }

    @Transactional
    public void deleteBanner(UUID id, UUID currentUserId) {
        AppBanner banner = bannerRepository.findById(id)
                .filter(b -> !Boolean.TRUE.equals(b.getIsDeleted()))
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy banner với ID: " + id));

        banner.softDelete(currentUserId);
        bannerRepository.save(banner);
        log.info("Đã xóa banner ID: {}", id);
    }

    private String saveImageFile(MultipartFile file) {
        try {
            String originalName = StringUtils.cleanPath(file.getOriginalFilename() != null ? file.getOriginalFilename() : "banner.png");
            if (originalName.contains("..")) {
                throw new BusinessException("Tên tệp không hợp lệ");
            }
            String ext = "";
            int dotIdx = originalName.lastIndexOf('.');
            if (dotIdx >= 0) {
                ext = originalName.substring(dotIdx).toLowerCase();
            }
            if (!List.of(".png", ".jpg", ".jpeg", ".webp", ".svg", ".gif").contains(ext)) {
                ext = ".png";
            }

            String filename = "banner_" + UUID.randomUUID() + ext;
            Path uploadPath = Paths.get(bannerUploadDir).normalize();
            if (!Files.exists(uploadPath)) {
                Files.createDirectories(uploadPath);
            }

            Path targetPath = uploadPath.resolve(filename).normalize();
            if (!targetPath.startsWith(uploadPath)) {
                throw new BusinessException("Đường dẫn tệp không hợp lệ");
            }

            Files.copy(file.getInputStream(), targetPath, StandardCopyOption.REPLACE_EXISTING);
            log.info("Đã lưu hình ảnh banner: {}", targetPath.toAbsolutePath());
            return "/api/v1/banners/images/" + filename;
        } catch (IOException e) {
            log.error("Lỗi khi lưu hình ảnh banner: {}", e.getMessage(), e);
            throw new BusinessException("Không thể lưu hình ảnh banner: " + e.getMessage());
        }
    }

    public Resource getImageResource(String filename) {
        try {
            if (!StringUtils.hasText(filename) || filename.contains("..") || filename.contains("/") || filename.contains("\\")) {
                throw new BusinessException("Tên tệp không hợp lệ");
            }
            Path filePath = Paths.get(bannerUploadDir).resolve(filename).normalize();
            Resource resource = new UrlResource(filePath.toUri());
            if (resource.exists() && resource.isReadable()) {
                return resource;
            }
            throw new ResourceNotFoundException("Không tìm thấy hình ảnh banner: " + filename);
        } catch (MalformedURLException e) {
            throw new ResourceNotFoundException("Không tìm thấy hình ảnh banner: " + filename);
        }
    }
}
