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

    @NotBlank(message = "Tiêu đề banner không được để trống")
    private String title;

    private String badgeText;

    private String subtitle;

    private String buttonText;

    @Builder.Default
    private String actionType = "BOOKING";

    private String actionValue;

    @Builder.Default
    private String buttonPosition = "BOTTOM_LEFT";

    private String buttonsJson;

    private java.util.List<BannerButtonDto> buttons;

    private String imageUrl;

    private String backgroundImageUrl;

    @Builder.Default
    private String gradientColors = "#2563EB,#4F46E5,#1D4ED8";

    @Builder.Default
    private Integer displayOrder = 0;

    @Builder.Default
    private Boolean isActive = true;

    private Instant startDate;

    private Instant endDate;
}
