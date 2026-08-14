package com.suachuabientan.system_internal.modules.attendance.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record FaceCheckinRequest(
        @NotBlank(message = "Anh khuon mat khong duoc de trong")
        @Size(max = 3_000_000, message = "Anh khuon mat vuot qua kich thuoc cho phep")
        String faceImageBase64,
        @NotBlank(message = "Loai anh khong duoc de trong")
        @Pattern(regexp = "image/(jpeg|png)", message = "Chi ho tro anh JPEG hoac PNG")
        String imageContentType,
        String deviceId
) {
}
