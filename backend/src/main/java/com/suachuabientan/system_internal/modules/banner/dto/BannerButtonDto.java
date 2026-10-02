package com.suachuabientan.system_internal.modules.banner.dto;

import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BannerButtonDto {
    private String text;

    @Builder.Default
    private String actionType = "BOOKING"; // BOOKING, REPAIR_ORDER, LINK, SCREEN, CALL, NONE

    private String actionValue;

    @Builder.Default
    private String styleType = "PRIMARY"; // PRIMARY, SECONDARY, OUTLINE
}
