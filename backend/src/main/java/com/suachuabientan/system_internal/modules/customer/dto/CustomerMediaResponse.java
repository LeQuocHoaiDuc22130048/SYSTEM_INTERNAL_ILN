package com.suachuabientan.system_internal.modules.customer.dto;

import java.time.Instant;
import java.util.UUID;

public record CustomerMediaResponse(
        UUID id,
        UUID mediaId,
        String mediaUrl,
        String fileUrl,
        String caption,
        Instant publishedAt
) {
    public CustomerMediaResponse(UUID id, UUID mediaId, String mediaUrl, String caption, Instant publishedAt) {
        this(id, mediaId, mediaUrl, mediaUrl, caption, publishedAt);
    }
}

