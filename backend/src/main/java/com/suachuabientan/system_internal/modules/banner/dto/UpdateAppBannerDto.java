package com.suachuabientan.system_internal.modules.banner.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.*;

import java.time.Instant;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UpdateAppBannerDto {

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

    private java.util.List<BannerButtonDto> buttons;

    private String imageUrl;

    private String imagePosition;
    private String fontFamily;

    private String designJson;

    private String backgroundImageUrl;

    private Boolean darkenOverlay;

    private String gradientColors;

    private Integer displayOrder;

    private Boolean isActive;

    private Instant startDate;

    private Instant endDate;
}
