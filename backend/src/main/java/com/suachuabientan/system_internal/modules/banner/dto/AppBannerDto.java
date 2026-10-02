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
    private String buttonsJson;
    private List<BannerButtonDto> buttons;
    private String imageUrl;
    private String backgroundImageUrl;
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
        if (parsedButtons.isEmpty() && StringUtils.hasText(banner.getButtonText())) {
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
                .buttonsJson(banner.getButtonsJson())
                .buttons(parsedButtons)
                .imageUrl(banner.getImageUrl())
                .backgroundImageUrl(banner.getBackgroundImageUrl())
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
