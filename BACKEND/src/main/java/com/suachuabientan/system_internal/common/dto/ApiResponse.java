package com.suachuabientan.system_internal.common.dto;

import lombok.*;
import lombok.experimental.FieldDefaults;

import java.time.LocalDateTime;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
@FieldDefaults(level = AccessLevel.PRIVATE)
public class ApiResponse<T> {
    String status;
    String message;
    T data;

    @Builder.Default
    LocalDateTime timestamp = LocalDateTime.now();

    // Helper method để tạo nhanh response thành công
    public static <T> ApiResponse<T> success(T data, String message) {
        return ApiResponse.<T>builder()
                .status("Thành công")
                .message(message)
                .data(data)
                .build();
    }
}
