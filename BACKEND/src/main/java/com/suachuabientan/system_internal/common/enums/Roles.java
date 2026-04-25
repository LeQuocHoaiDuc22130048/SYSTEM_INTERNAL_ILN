package com.suachuabientan.system_internal.common.enums;

import lombok.AccessLevel;
import lombok.Getter;
import lombok.experimental.FieldDefaults;

@Getter
@FieldDefaults(level = AccessLevel.PRIVATE, makeFinal = true)
public enum Roles {
    ADMIN("ADMIN"),
    BOSS("Giám đốc"),
    MANAGER("Accountant"),
    STAFF("Nhân viên");

    String displayName;

    Roles(String displayName) {
        this.displayName = displayName;
    }
}
