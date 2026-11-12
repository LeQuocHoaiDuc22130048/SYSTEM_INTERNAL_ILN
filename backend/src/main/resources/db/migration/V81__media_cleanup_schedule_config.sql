-- =====================================================================
-- V81: Cấu hình lịch hẹn chạy Media Cleanup động từ giao diện Admin
-- Cho phép Admin hẹn đúng ngày giờ xác định để chạy (không chạy liên tục)
-- =====================================================================

CREATE TABLE IF NOT EXISTS media_cleanup_schedule_config (
    id                              INT PRIMARY KEY DEFAULT 1,
    is_enabled                      BOOLEAN NOT NULL DEFAULT TRUE,
    schedule_mode                   VARCHAR(30) NOT NULL DEFAULT 'SPECIFIC_DATETIME', -- SPECIFIC_DATETIME, MONTHLY, WEEKLY, DAILY
    scheduled_run_at                TIMESTAMP WITH TIME ZONE,
    day_of_month                    INT DEFAULT 1,
    day_of_week                     INT DEFAULT 1,
    time_of_day                     VARCHAR(10) NOT NULL DEFAULT '02:00',
    unreferenced_upload_ttl_hours   BIGINT NOT NULL DEFAULT 24,
    deleted_message_media_ttl_days  BIGINT NOT NULL DEFAULT 7,
    closed_repair_media_ttl_days    BIGINT NOT NULL DEFAULT 180,
    last_triggered_at               TIMESTAMP WITH TIME ZONE,
    updated_by                      VARCHAR(100),
    updated_at                      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_single_schedule_row CHECK (id = 1)
);

INSERT INTO media_cleanup_schedule_config (
    id,
    is_enabled,
    schedule_mode,
    scheduled_run_at,
    day_of_month,
    day_of_week,
    time_of_day,
    unreferenced_upload_ttl_hours,
    deleted_message_media_ttl_days,
    closed_repair_media_ttl_days
) VALUES (
    1,
    FALSE,
    'SPECIFIC_DATETIME',
    NULL,
    1,
    1,
    '02:00',
    24,
    7,
    180
) ON CONFLICT (id) DO NOTHING;

