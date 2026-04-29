package com.suachuabientan.system_internal.common.enums;

import lombok.AccessLevel;
import lombok.Getter;
import lombok.experimental.FieldDefaults;

@Getter
@FieldDefaults(level = AccessLevel.PRIVATE, makeFinal = true)
public enum UserRole {
    SUPER_ADMIN,
    ADMIN,
    MANAGER,
    EMPLOYEE
}
