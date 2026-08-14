package com.suachuabientan.system_internal.modules.health.dto;

import java.time.Instant;
import java.util.Map;

public record HealthResponse(
        String status,
        Instant timestamp,
        long uptimeSeconds,
        Map<String, HealthCheckResponse> checks
) {
}
