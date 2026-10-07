package com.suachuabientan.system_internal.modules.banner.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "app_banners")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AppBanner extends BaseEntity {

    @Column(name = "title", length = 255)
    private String title;

    @Column(name = "badge_text", length = 100)
    private String badgeText;

    @Column(length = 500)
    private String subtitle;

    @Column(name = "button_text", length = 100)
    private String buttonText;

    @Column(name = "action_type", length = 50, nullable = false)
    @Builder.Default
    private String actionType = "BOOKING";

    @Column(name = "action_value", length = 500)
    private String actionValue;

    @Column(name = "button_position", length = 50, nullable = false)
    @Builder.Default
    private String buttonPosition = "BOTTOM_LEFT";

    @Column(name = "button_top")
    private Double buttonTop;

    @Column(name = "button_bottom")
    private Double buttonBottom;

    @Column(name = "button_left")
    private Double buttonLeft;

    @Column(name = "button_right")
    private Double buttonRight;

    @Column(name = "buttons_json", columnDefinition = "TEXT")
    private String buttonsJson;

    @Column(name = "image_url", length = 500)
    private String imageUrl;

    @Column(name = "image_position", length = 50, nullable = false)
    @Builder.Default
    private String imagePosition = "RIGHT";

    @Column(name = "font_family", length = 100, nullable = false)
    @Builder.Default
    private String fontFamily = "Be Vietnam Pro";

    @Column(name = "design_json", columnDefinition = "TEXT")
    private String designJson;

    @Column(name = "background_image_url", length = 500)
    private String backgroundImageUrl;

    @Column(name = "darken_overlay", nullable = false)
    @Builder.Default
    private Boolean darkenOverlay = false;

    @Column(name = "gradient_colors", length = 200, nullable = false)
    @Builder.Default
    private String gradientColors = "#2563EB,#4F46E5,#1D4ED8";

    @Column(name = "display_order", nullable = false)
    @Builder.Default
    private Integer displayOrder = 0;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private Boolean isActive = true;

    @Column(name = "start_date")
    private Instant startDate;

    @Column(name = "end_date")
    private Instant endDate;
}
