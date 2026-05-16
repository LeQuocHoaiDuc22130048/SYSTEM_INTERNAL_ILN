package com.suachuabientan.system_internal.modules.messaging.dto.request;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.UUID;

public record CreateConversationRequest(
        @NotBlank(message = "Loai cuoc tro chuyen khong duoc de trong")
        String type,

        @Size(max = 100, message = "Tên nhóm tối đa 100 ký tự")
        String name,

        /**
         * Danh sách UUID thành viên (không bao gồm người tạo).
         * DIRECT: đúng 1 người.
         * GROUP: ít nhất 2 người.
         */
        @NotEmpty(message = "Phải có ít nhất 1 thành viên")
        List<UUID> memberIds
) {
}
