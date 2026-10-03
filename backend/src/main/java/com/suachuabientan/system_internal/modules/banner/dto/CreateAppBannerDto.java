package com.suachuabientan.system_internal.modules.banner.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.*;

import java.time.Instant;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CreateAppBannerDto {

    private String title;

    private String badgeText;

    private String subtitle;

    private String buttonText;

    @Builder.Default
    private String actionType = "BOOKING";

    private String actionValue;

    @Builder.Default
    private String buttonPosition = "BOTTOM_LEFT";

    private Double buttonTop;
    private Double buttonBottom;
    private Double buttonLeft;
    private Double buttonRight;

    private String buttonsJson;

    private java.util.List<BannerButtonDto> buttons;

    private String imageUrl;

    @Builder.Default
    private String imagePosition = "RIGHT";

    @Builder.Default
    private String fontFamily = "Be Vietnam Pro";

    private String backgroundImageUrl;

    @Builder.Default
    private Boolean darkenOverlay = false;

    @Builder.Default
    private String gradientColors = "#2563EB,#4F46E5,#1D4ED8";

    @Builder.Default
    private Integer displayOrder = 0;

    @Builder.Default
    private Boolean isActive = true;

    private Instant startDate;

    private Instant endDate;
}
