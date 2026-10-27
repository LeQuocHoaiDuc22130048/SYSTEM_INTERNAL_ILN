package com.suachuabientan.system_internal.common.exception;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.authentication.LockedException;
import org.springframework.security.core.AuthenticationException;

import static org.junit.jupiter.api.Assertions.assertEquals;

class GlobalExceptionHandlerTest {

    private GlobalExceptionHandler handler;

    @BeforeEach
    void setUp() {
        handler = new GlobalExceptionHandler();
    }

    @Test
    void handleBadCredentialsReturns401() {
        ResponseEntity<ApiResponse<Void>> response = handler.handleBadCredentials(new BadCredentialsException("Bad credentials"));
        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
        assertEquals(401, response.getBody().getCode());
    }

    @Test
    void handleLockedReturns403() {
        ResponseEntity<ApiResponse<Void>> response = handler.handleLocked(new LockedException("User account is locked"));
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        assertEquals(403, response.getBody().getCode());
    }

    @Test
    void handleDisabledReturns403() {
        ResponseEntity<ApiResponse<Void>> response = handler.handleDisabled(new DisabledException("User is disabled"));
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        assertEquals(403, response.getBody().getCode());
    }

    @Test
    void handleAuthenticationReturns401() {
        ResponseEntity<ApiResponse<Void>> response = handler.handleAuthentication(new AuthenticationException("Generic auth error") {});
        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
        assertEquals(401, response.getBody().getCode());
    }
}
