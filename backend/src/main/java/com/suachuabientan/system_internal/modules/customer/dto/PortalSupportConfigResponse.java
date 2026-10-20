package com.suachuabientan.system_internal.modules.customer.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PortalSupportConfigResponse {
    private String hotlineNumber;
    private String hotlineLabel;
    private String zaloUrl;
    private String zaloLabel;
    private String workingHours;
    private String workshopAddress;
    private LocalDateTime updatedAt;
}
