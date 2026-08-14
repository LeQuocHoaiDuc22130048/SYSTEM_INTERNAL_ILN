ALTER TABLE attendance_records
    ADD COLUMN IF NOT EXISTS mobile_check_time TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_attendance_records_mobile_dedup
    ON attendance_records (employee_id, type, mobile_check_time)
    WHERE is_deleted = false AND is_valid = true AND mobile_check_time IS NOT NULL;
