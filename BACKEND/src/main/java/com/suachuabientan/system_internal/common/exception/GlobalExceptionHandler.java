package com.suachuabientan.system_internal.common.exception;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.common.enums.ErrorCode;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.LocalDateTime;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiResponse<String>> handleBusinessException(BusinessException e) {
        ErrorCode errorCode = e.getErrorCode();

        ApiResponse<String> response = ApiResponse.<String>builder()
                .status("Thất bại")
                .message(errorCode.getMessage())
                .data(errorCode.getCode())
                .timestamp(LocalDateTime.now()) 
                .build();
        return new ResponseEntity<>(response, errorCode.getHttpStatus());
    }
}
