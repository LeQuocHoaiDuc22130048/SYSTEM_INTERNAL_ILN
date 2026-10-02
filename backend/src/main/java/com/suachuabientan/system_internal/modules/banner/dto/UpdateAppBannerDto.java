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

    @NotBlank(message = "Tiêu đề banner không được để trống")
    private String title;

    private String badgeText;

    private String subtitle;

    private String buttonText;

    private String actionType;

    private String actionValue;

    private String buttonPosition;

    private String buttonsJson;

    private java.util.List<BannerButtonDto> buttons;

    private String imageUrl;

    private String backgroundImageUrl;

    private String gradientColors;

    private Integer displayOrder;

    private Boolean isActive;

    private Instant startDate;

    private Instant endDate;
}
