package com.suachuabientan.system_internal.modules.customer.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UpdatePortalSupportConfigRequest {

    @NotBlank(message = "Số hotline không được để trống")
    private String hotlineNumber;

    private String hotlineLabel;

    @NotBlank(message = "Đường dẫn Zalo không được để trống")
    private String zaloUrl;

    private String zaloLabel;

    private String workingHours;

    private String workshopAddress;
}
