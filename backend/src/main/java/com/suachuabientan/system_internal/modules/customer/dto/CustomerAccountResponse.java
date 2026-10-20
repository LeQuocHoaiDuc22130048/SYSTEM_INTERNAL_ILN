package com.suachuabientan.system_internal.modules.customer.dto;

import java.time.Instant;
import java.util.UUID;

public record CustomerAccountResponse(
        UUID id,
        UUID userId,
        UUID customerId,
        String username,
        String contactName,
        String phone,
        String email,
        boolean active,
        boolean mustChangePassword,
        Instant createdAt
) {
}
