package com.suachuabientan.system_internal.modules.terminal.dto;

import java.time.Instant;

public record SystemActivityDto(
        String id,
        Instant timestamp,
        String category,
        String action,
        String details,
        String username,
        String role,
        String ip,
        String status,
        Long latencyMs
) {
    public static SystemActivityDto create(
            String category,
            String action,
            String details,
            String username,
            String role,
            String ip,
            String status,
            Long latencyMs) {
        return new SystemActivityDto(
                java.util.UUID.randomUUID().toString(),
                Instant.now(),
                category != null ? category : "SYSTEM",
                action != null ? action : "UNKNOWN",
                details != null ? details : "",
                username != null ? username : "system",
                role != null ? role : "",
                ip != null ? ip : "127.0.0.1",
                status != null ? status : "INFO",
                latencyMs
        );
    }
}
