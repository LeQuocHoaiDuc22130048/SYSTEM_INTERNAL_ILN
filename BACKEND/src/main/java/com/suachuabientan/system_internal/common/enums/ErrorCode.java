package com.suachuabientan.system_internal.common.enums;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.experimental.FieldDefaults;
import org.springframework.http.HttpStatus;

@Getter
@AllArgsConstructor
@FieldDefaults(level = lombok.AccessLevel.PRIVATE, makeFinal = true)
public enum ErrorCode {
    SYSTEM_ERROR(999, "Lỗi hệ thống không xác định", HttpStatus.INTERNAL_SERVER_ERROR),
    INVALID_INPUT(100, "Dữ liệu đầu vào không hợp lệ", HttpStatus.BAD_REQUEST),

    UNAUTHORIZED(300, "Tên đăng nhập hoặc mật khẩu không chính xác", HttpStatus.UNAUTHORIZED),
    AUTH_002(301, "Tài khoản của bạn đã bị vô hiệu hóa. Vui lòng liên hệ quản trị viên.", HttpStatus.FORBIDDEN),
    AUTH_003(302, "Nhân viên đã tồn tại", HttpStatus.BAD_REQUEST),
    USER_NOT_FOUND(303, "Người dùng không tồn tại", HttpStatus.NOT_FOUND),
    INVALID_REFRESH_TOKEN(304, "Refresh token không hợp lệ", HttpStatus.UNAUTHORIZED),
    REFRESH_TOKEN_EXPIRED(305, "Refresh token đã hết hạn", HttpStatus.UNAUTHORIZED),

    QR_NOT_FOUND(400, "Mã QR không tồn tại trên hệ thống", HttpStatus.NOT_FOUND),
    DUPLICATE_ACTION(401    , "Thao tác này đã được thực hiện", HttpStatus.CONFLICT);

    int code;
    String message;
    HttpStatus httpStatus;
}
