package com.suachuabientan.system_internal.modules.banner.dto;

import jakarta.validation.constraints.NotEmpty;
import lombok.*;

import java.util.List;
import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ReorderBannersDto {
    @NotEmpty(message = "Danh sách ID không được để trống")
    private List<UUID> bannerIds;
}
