package com.suachuabientan.system_internal.modules.quotation.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.util.List;
import java.util.UUID;

public record CreateQuotationItemRequest(
        @NotNull(message = "Mã đơn sửa chữa không được để trống")
        UUID repairOrderId,
        @Valid
        List<DiagnosedErrorDto> diagnosedErrors,
        @NotEmpty(message = "Mỗi thiết bị phải có ít nhất 1 hạng mục báo giá")
        @Valid
        List<QuotationLineItemRequest> lineItems,
        @Valid
        List<WarrantyOptionDto> warrantyOptions
) {
}

