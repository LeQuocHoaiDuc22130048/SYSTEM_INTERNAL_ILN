package com.suachuabientan.system_internal.modules.quotation.enums;

public enum QuotationItemDecision {
    PENDING("Chờ duyệt"),
    APPROVED("Đồng ý sửa"),
    REJECTED("Từ chối");

    private final String label;

    QuotationItemDecision(String label) {
        this.label = label;
    }

    public String getLabel() {
        return label;
    }
}

