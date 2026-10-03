package com.suachuabientan.system_internal.modules.banner.dto;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.suachuabientan.system_internal.modules.banner.entity.AppBanner;
import lombok.*;
import org.springframework.util.StringUtils;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AppBannerDto {
    private UUID id;
    private String title;
    private String badgeText;
    private String subtitle;
    private String buttonText;
    private String actionType;
    private String actionValue;
    private String buttonPosition;
    private Double buttonTop;
    private Double buttonBottom;
    private Double buttonLeft;
    private Double buttonRight;
    private String buttonsJson;
    private List<BannerButtonDto> buttons;
    private String imageUrl;
    private String imagePosition;
    private String fontFamily;
    private String backgroundImageUrl;
    @Builder.Default
    private Boolean darkenOverlay = false;
    private String gradientColors;
    private Integer displayOrder;
    private Boolean isActive;
    private Instant startDate;
    private Instant endDate;
    private Instant createdAt;
    private Instant updatedAt;

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    public static AppBannerDto fromEntity(AppBanner banner) {
        if (banner == null) return null;

        List<BannerButtonDto> parsedButtons = new ArrayList<>();
        if (StringUtils.hasText(banner.getButtonsJson())) {
            try {
                parsedButtons = OBJECT_MAPPER.readValue(banner.getButtonsJson(), new TypeReference<List<BannerButtonDto>>() {});
            } catch (Exception ignored) {}
        }
        if (banner.getButtonsJson() == null && parsedButtons.isEmpty() && StringUtils.hasText(banner.getButtonText())) {
            parsedButtons.add(BannerButtonDto.builder()
                    .text(banner.getButtonText())
                    .actionType(StringUtils.hasText(banner.getActionType()) ? banner.getActionType() : "BOOKING")
                    .actionValue(banner.getActionValue())
                    .styleType("PRIMARY")
                    .build());
        }

        return AppBannerDto.builder()
                .id(banner.getId())
                .title(banner.getTitle())
                .badgeText(banner.getBadgeText())
                .subtitle(banner.getSubtitle())
                .buttonText(banner.getButtonText())
                .actionType(banner.getActionType())
                .actionValue(banner.getActionValue())
                .buttonPosition(StringUtils.hasText(banner.getButtonPosition()) ? banner.getButtonPosition() : "BOTTOM_LEFT")
                .buttonTop(banner.getButtonTop())
                .buttonBottom(banner.getButtonBottom())
                .buttonLeft(banner.getButtonLeft())
                .buttonRight(banner.getButtonRight())
                .buttonsJson(banner.getButtonsJson())
                .buttons(parsedButtons)
                .imageUrl(banner.getImageUrl())
                .imagePosition(StringUtils.hasText(banner.getImagePosition()) ? banner.getImagePosition() : "RIGHT")
                .fontFamily(StringUtils.hasText(banner.getFontFamily()) ? banner.getFontFamily() : "Be Vietnam Pro")
                .backgroundImageUrl(banner.getBackgroundImageUrl())
                .darkenOverlay(banner.getDarkenOverlay() != null ? banner.getDarkenOverlay() : false)
                .gradientColors(banner.getGradientColors())
                .displayOrder(banner.getDisplayOrder())
                .isActive(banner.getIsActive())
                .startDate(banner.getStartDate())
                .endDate(banner.getEndDate())
                .createdAt(banner.getCreatedAt())
                .updatedAt(banner.getUpdatedAt())
                .build();
    }
}
