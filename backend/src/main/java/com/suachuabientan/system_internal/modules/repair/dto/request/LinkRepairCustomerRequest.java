package com.suachuabientan.system_internal.modules.repair.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.UUID;

public record LinkRepairCustomerRequest(@NotNull UUID customerId,
        @NotBlank @Size(max = 500) String reason) { }
