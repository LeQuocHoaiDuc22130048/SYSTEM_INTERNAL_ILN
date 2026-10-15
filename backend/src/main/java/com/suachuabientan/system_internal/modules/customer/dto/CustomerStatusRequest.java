package com.suachuabientan.system_internal.modules.customer.dto;

import jakarta.validation.constraints.NotNull;

public record CustomerStatusRequest(@NotNull Boolean active) { }
