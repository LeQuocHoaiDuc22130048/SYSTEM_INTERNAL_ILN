package com.suachuabientan.system_internal.modules.customer.dto;

import java.time.Instant;
import java.util.UUID;

public record CustomerUpdateResponse(
        UUID id,
        String title,
        String message,
        String content,
        String statusAtTime,
        String statusAtUpdate,
        Instant publishedAt
) {
    public CustomerUpdateResponse(UUID id, String title, String message, String statusAtTime, Instant publishedAt) {
        this(id, title, message, message, statusAtTime, statusAtTime, publishedAt);
    }
}

