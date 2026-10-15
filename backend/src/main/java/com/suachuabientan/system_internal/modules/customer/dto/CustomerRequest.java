package com.suachuabientan.system_internal.modules.customer.dto;

import com.suachuabientan.system_internal.modules.customer.enums.CustomerType;
import jakarta.validation.constraints.*;

public record CustomerRequest(
        @NotBlank @Size(max = 100) String customerName,
        @NotNull CustomerType type,
        @Size(max = 20) String phone,
        @Email @Size(max = 254) String email,
        @Size(max = 500) String address,
        @Size(max = 30) String taxCode,
        @Size(max = 2000) String notes
) { }
