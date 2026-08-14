ALTER TABLE attendance_records
    ADD COLUMN IF NOT EXISTS device_log_id VARCHAR(120);

CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_records_device_log_id
    ON attendance_records(device_log_id)
    WHERE device_log_id IS NOT NULL AND is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_attendance_records_employee_time_type
    ON attendance_records(employee_id, check_time, type)
    WHERE is_deleted = false;
