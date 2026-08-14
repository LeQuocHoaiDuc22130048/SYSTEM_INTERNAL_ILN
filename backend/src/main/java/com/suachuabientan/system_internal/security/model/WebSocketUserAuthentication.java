package com.suachuabientan.system_internal.security.model;

import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;

public class WebSocketUserAuthentication extends UsernamePasswordAuthenticationToken {
    private final String name;

    public WebSocketUserAuthentication(CustomUserDetails userDetails) {
        super(userDetails, null, userDetails.getAuthorities());
        this.name = userDetails.getUserId().toString();
    }

    @Override
    public String getName() {
        return name;
    }
}
