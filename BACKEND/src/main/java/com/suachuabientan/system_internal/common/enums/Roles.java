package com.suachuabientan.system_internal.common.enums;

import lombok.AccessLevel;
import lombok.Getter;
import lombok.experimental.FieldDefaults;

@Getter
@FieldDefaults(level = AccessLevel.PRIVATE, makeFinal = true)
public enum Roles {
    BOSS("Giám đốc"),
    ADMIN("Quản trị viên"),
    MANAGER("Kế toán"),
    STAFF("Nhân viên kho");

    String displayName;

    Roles(String displayName) {
        this.displayName = displayName;
    }
}
