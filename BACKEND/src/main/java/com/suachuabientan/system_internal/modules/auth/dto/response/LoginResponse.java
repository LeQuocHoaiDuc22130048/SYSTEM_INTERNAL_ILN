package com.suachuabientan.system_internal.modules.auth.dto.response;

import java.util.List;

public record LoginResponse(
        String accessToken,
        String refreshToken,
        String tokenType,
        Long expiresIn,
        UserInfo userInfo
) {
    public record UserInfo (
            java.util.UUID id,
            String username,
            String fullName,
            String role,
            String status,
            String avatarUrl,
            Object department,
            List<String> permissions
    ){}
}
