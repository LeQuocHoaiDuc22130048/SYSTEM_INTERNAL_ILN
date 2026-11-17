package com.suachuabientan.system_internal.modules.quotation.enums;

public enum QuotationStatus {
    DRAFT("Nháp"),
    SENT("Chờ khách duyệt"),
    PARTIAL_APPROVED("Duyệt một phần"),
    APPROVED("Đã duyệt toàn bộ"),
    REJECTED("Đã từ chối"),
    EXPIRED("Hết hạn"),
    CANCELLED("Đã hủy");

    private final String label;

    QuotationStatus(String label) {
        this.label = label;
    }

    public String getLabel() {
        return label;
    }
}

