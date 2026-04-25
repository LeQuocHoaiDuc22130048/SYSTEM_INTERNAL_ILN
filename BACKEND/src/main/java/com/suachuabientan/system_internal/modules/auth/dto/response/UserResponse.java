package com.suachuabientan.system_internal.modules.auth.dto.response;

import lombok.Data;
import lombok.experimental.FieldDefaults;

import java.time.LocalDateTime;

@Data
@FieldDefaults(level = lombok.AccessLevel.PRIVATE)
public class UserResponse {
    Long id;
    String username;
    String fullName;
    String email;
    String role;
    boolean isActive;
    LocalDateTime createdAt;
}
