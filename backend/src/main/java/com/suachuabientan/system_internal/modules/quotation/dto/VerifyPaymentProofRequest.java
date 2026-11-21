package com.suachuabientan.system_internal.modules.quotation.dto;

public record VerifyPaymentProofRequest(
        boolean approved,
        String rejectionReason
) {
}

