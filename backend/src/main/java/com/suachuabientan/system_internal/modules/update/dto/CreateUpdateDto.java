package com.suachuabientan.system_internal.modules.update.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateUpdateDto(
    @NotBlank(message = "Phiên bản không được để trống")
    @Size(max = 50, message = "Phiên bản không vượt quá 50 ký tự")
    String version,

    @NotBlank(message = "Chi tiết cập nhật không được để trống")
    String changelog,

    @NotBlank(message = "Link tải không được để trống")
    @Size(max = 500, message = "Link tải không vượt quá 500 ký tự")
    String downloadUrl,

    Boolean mandatory,

    @Size(max = 20, message = "Trạng thái không vượt quá 20 ký tự")
    String status,

    @Size(max = 20, message = "Nền tảng không vượt quá 20 ký tự")
    String platform,

    @Size(max = 50, message = "Phiên bản hỗ trợ tối thiểu không vượt quá 50 ký tự")
    String minSupportedVersion,

    @Size(max = 20, message = "Kênh phát hành không vượt quá 20 ký tự")
    String channel,

    @Size(max = 64, message = "Mã băm SHA-256 không vượt quá 64 ký tự")
    String sha256,

    Long fileSize
) {}
