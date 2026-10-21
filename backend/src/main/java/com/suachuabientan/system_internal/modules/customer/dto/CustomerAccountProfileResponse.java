package com.suachuabientan.system_internal.modules.customer.dto;

import java.util.UUID;

public record CustomerAccountProfileResponse(
        UUID userId,
        String username,
        String contactName,
        String phone,
        String email,
        String avatarUrl,
        UUID customerId,
        String customerCode,
        String customerName,
        String companyAddress,
        String companyTaxCode
) {}
