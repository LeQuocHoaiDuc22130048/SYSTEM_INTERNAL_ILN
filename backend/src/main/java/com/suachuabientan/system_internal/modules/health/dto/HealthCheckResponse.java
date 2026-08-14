package com.suachuabientan.system_internal.modules.health.dto;

import java.util.Map;

public record HealthCheckResponse(
        String status,
        String message,
        Map<String, Object> details
) {
    public static HealthCheckResponse up(String message, Map<String, Object> details) {
        return new HealthCheckResponse("UP", message, details);
    }

    public static HealthCheckResponse down(String message, Map<String, Object> details) {
        return new HealthCheckResponse("DOWN", message, details);
    }
}
