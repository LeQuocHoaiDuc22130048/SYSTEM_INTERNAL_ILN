package com.suachuabientan.system_internal.common.enums;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.experimental.FieldDefaults;
import org.springframework.http.HttpStatus;

@Getter
@AllArgsConstructor
@FieldDefaults(level = lombok.AccessLevel.PRIVATE, makeFinal = true)
public enum ErrorCode {
    SYSTEM_ERROR("ERR_000", "Lỗi hệ thống không xác định", HttpStatus.INTERNAL_SERVER_ERROR),
    INVALID_INPUT("ERR_001", "Dữ liệu đầu vào không hợp lệ", HttpStatus.BAD_REQUEST),

    UNAUTHORIZED("AUTH_001", "Tên đăng nhập hoặc mật khẩu không chính xác", HttpStatus.UNAUTHORIZED),
    AUTH_002("AUTH_002", "Tài khoản của bạn đã bị vô hiệu hóa. Vui lòng liên hệ quản trị viên.", HttpStatus.FORBIDDEN),

    QR_NOT_FOUND("INV_001", "Mã QR không tồn tại trên hệ thống", HttpStatus.NOT_FOUND),
    DUPLICATE_ACTION("INV_002", "Thao tác này đã được thực hiện", HttpStatus.CONFLICT);

    String code;
    String message;
    HttpStatus httpStatus;
}
