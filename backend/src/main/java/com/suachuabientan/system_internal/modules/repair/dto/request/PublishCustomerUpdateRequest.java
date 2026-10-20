package com.suachuabientan.system_internal.modules.repair.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.UUID;

public record PublishCustomerUpdateRequest(
        UUID deviceId,

        @NotBlank(message = "Tiêu đề không được để trống")
        @Size(max = 200, message = "Tiêu đề tối đa 200 ký tự")
        String title,

        String message,

        String content
) {
    public PublishCustomerUpdateRequest(UUID deviceId, String title, String message) {
        this(deviceId, title, message, message);
    }

    public String resolveMessage() {
        if (message != null && !message.isBlank()) {
            return message.strip();
        }
        if (content != null && !content.isBlank()) {
            return content.strip();
        }
        return "";
    }
}

