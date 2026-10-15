package com.suachuabientan.system_internal.modules.customer.dto;

import com.suachuabientan.system_internal.modules.customer.enums.CustomerType;
import java.time.Instant;
import java.util.UUID;

public record CustomerResponse(UUID id, String customerCode, String customerName,
        CustomerType type, String phone, String email, String address, String taxCode,
        String notes, boolean active, Instant createdAt, Instant updatedAt) { }
