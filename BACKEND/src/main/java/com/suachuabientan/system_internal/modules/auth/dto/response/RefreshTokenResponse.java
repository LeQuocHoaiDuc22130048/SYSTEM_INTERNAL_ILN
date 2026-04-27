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
public class RefreshTokenResponse {
    String accessToken;
    String refreshToken;
    
    @Builder.Default
    String tokenType = "Bearer";
}