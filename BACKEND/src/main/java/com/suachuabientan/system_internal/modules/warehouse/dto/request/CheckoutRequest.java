package com.suachuabientan.system_internal.modules.warehouse.dto.request;

import java.util.UUID;

public record CheckoutRequest(
        UUID repairOrderId,
        String note
) {
}
