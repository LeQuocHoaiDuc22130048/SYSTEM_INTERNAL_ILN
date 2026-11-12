package com.suachuabientan.system_internal.modules.mediacleanup.enums;

public enum CleanupScheduleMode {
    /**
     * Chỉ chạy đúng 1 lần khi đến mốc Ngày & Giờ xác định do Admin hẹn (Không tự chạy lặp lại hàng ngày).
     */
    SPECIFIC_DATETIME,

    /**
     * Chạy định kỳ mỗi tháng 1 lần vào ngày và giờ xác định.
     */
    MONTHLY,

    /**
     * Chạy định kỳ mỗi tuần 1 lần vào thứ và giờ xác định.
     */
    WEEKLY,

    /**
     * Chạy định kỳ hàng ngày vào giờ xác định.
     */
    DAILY
}

