package com.suachuabientan.system_internal.modules.mediacleanup.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Getter
@Setter
@Configuration
@ConfigurationProperties(prefix = "app.media-cleanup")
public class MediaCleanupProperties {

    /**
     * Bật/tắt chạy Media Cleanup Engine.
     */
    private boolean enabled = true;

    /**
     * Biểu thức Cron chạy định kỳ (Mặc định: 02:00 AM hằng ngày).
     */
    private String cron = "0 0 2 * * *";

    /**
     * Số lượng bản ghi xử lý mỗi batch (Quyết định thiết kế: 100 records/batch).
     */
    private int batchSize = 100;

    /**
     * Giới hạn số batch tối đa trong một phiên chạy để tránh chạy vô hạn.
     */
    private int maxBatchesPerRun = 100;

    /**
     * Số lần retry tối đa trước khi đánh dấu FAILED_PERMANENT.
     */
    private int maxRetries = 5;

    /**
     * Thời gian chờ cơ sở (phút) cho thuật toán Exponential Backoff.
     */
    private long baseBackoffMinutes = 5;

    /**
     * Thời gian chờ tối đa (phút) cho Exponential Backoff.
     */
    private long maxBackoffMinutes = 360;

    /**
     * Ngưỡng thời gian (phút) xác định bản ghi CLEANUP_IN_PROGRESS hoặc Job RUNNING bị treo do restart.
     */
    private long stuckTimeoutMinutes = 15;

    /**
     * Thời hạn mặc định (giờ) cho tệp vừa tải lên nhưng chưa gắn reference.
     */
    private long unreferencedUploadTtlHours = 24;

    /**
     * Thời hạn lưu giữ (ngày) cho media thuộc tin nhắn đã xóa.
     */
    private long deletedMessageMediaTtlDays = 7;

    /**
     * Thời hạn lưu giữ (ngày) cho media thuộc đơn sửa chữa đã đóng/hoàn tất.
     */
    private long closedRepairMediaTtlDays = 180;
}

