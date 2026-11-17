package com.suachuabientan.system_internal.modules.quotation.enums;

public enum PaymentProofStatus {
    PENDING_VERIFY("Chờ đối soát"),
    VERIFIED("Đã xác nhận"),
    REJECTED("Từ chối chứng từ");

    private final String label;

    PaymentProofStatus(String label) {
        this.label = label;
    }

    public String getLabel() {
        return label;
    }
}

