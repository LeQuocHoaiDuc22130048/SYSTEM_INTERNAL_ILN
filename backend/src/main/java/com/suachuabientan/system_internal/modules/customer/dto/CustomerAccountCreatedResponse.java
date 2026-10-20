package com.suachuabientan.system_internal.modules.customer.dto;

public record CustomerAccountCreatedResponse(
        CustomerAccountResponse account,
        String plainPassword,
        String shareableMessage
) {
}
