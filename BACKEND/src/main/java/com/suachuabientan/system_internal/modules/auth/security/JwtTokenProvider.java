package com.suachuabientan.system_internal.modules.auth.security;

import lombok.experimental.FieldDefaults;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
@FieldDefaults(level = lombok.AccessLevel.PRIVATE)
public class JwtTokenProvider {

    @Value("${app.jwt.secret}")
    String jwtSecret;

    @Value("${app.jwt.expiration-ms}")
    Long jwtExpirationMs;



}
