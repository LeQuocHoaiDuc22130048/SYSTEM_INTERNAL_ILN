package com.suachuabientan.system_internal.common.enums;

import lombok.AccessLevel;
import lombok.Getter;
import lombok.experimental.FieldDefaults;

@Getter
@FieldDefaults(level = AccessLevel.PRIVATE, makeFinal = true)
public enum BusinessStatus {
    SUCCESS("Thành công"),
    FAILURE("Thất bại");

    String message;

    BusinessStatus(String message) {
        this.message = message;
    }
}
