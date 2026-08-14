package com.suachuabientan.system_internal.modules.warehouse.dto.response;

import com.suachuabientan.system_internal.modules.warehouse.enums.CheckoutStatus;
import com.suachuabientan.system_internal.modules.warehouse.enums.PartCondition;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record PartCheckoutHistoryResponse(
        UUID id,
        UUID partId,
        String partIpn,
        String partName,
        UUID storeLocationId,
        String locationCode,
        String locationName,
        UUID takenBy,
        String takenByName,
        String takenByEmployeeCode,
        BigDecimal quantity,
        BigDecimal returnedQuantity,
        Instant takenAt,
        Instant returnedAt,
        String purpose,
        UUID repairOrderId,
        PartCondition conditionStatus,
        CheckoutStatus checkoutStatus,
        String notes
) {}
