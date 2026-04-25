package com.suachuabientan.system_internal.modules.auth.dto.request;

import lombok.AccessLevel;
import lombok.Data;
import lombok.experimental.FieldDefaults;

@Data
@FieldDefaults(level= AccessLevel.PRIVATE)
public class LoginRequest {
    String username;
    String password;
}
