package com.suachuabientan.system_internal.modules.auth.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.experimental.FieldDefaults;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
@FieldDefaults(level = lombok.AccessLevel.PRIVATE)
public class LoginResponse {
    String accessToken;
    String tokenType = "Bearer";
    String username;
    String fullName;
    String role;
}
