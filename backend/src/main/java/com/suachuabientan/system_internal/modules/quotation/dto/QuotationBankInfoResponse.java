package com.suachuabientan.system_internal.modules.quotation.dto;

import java.math.BigDecimal;

public record QuotationBankInfoResponse(
        String bankName,
        String bankBin,
        String bankAccountNumber,
        String bankAccountHolder,
        String transferContent,
        BigDecimal transferAmount,
        String vietQrPayload
) {
}

