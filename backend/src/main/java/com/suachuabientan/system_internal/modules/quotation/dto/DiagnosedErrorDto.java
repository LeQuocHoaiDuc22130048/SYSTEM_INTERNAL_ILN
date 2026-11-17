package com.suachuabientan.system_internal.modules.quotation.dto;

import jakarta.validation.constraints.NotBlank;

public record DiagnosedErrorDto(
        @NotBlank(message = "Mô tả lỗi không được để trống")
        String label,
        String severity
) {
}

