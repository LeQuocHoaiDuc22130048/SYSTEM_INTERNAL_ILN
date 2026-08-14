-- Hot attendance queries:
-- 1. Employee history: employee_id + check_time range, ordered by check_time DESC.
-- 2. Daily report: check_time range for all employees.
-- 3. Valid status filters: is_valid + is_deleted are used by attendance summaries/dedup.

CREATE INDEX IF NOT EXISTS idx_attendance_records_employee_check_time_desc
    ON attendance_records (employee_id, check_time DESC)
    WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_attendance_records_day_check_time
    ON attendance_records (check_time)
    WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_attendance_records_valid_status_time
    ON attendance_records (is_valid, check_time)
    WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_attendance_records_employee_valid_time
    ON attendance_records (employee_id, is_valid, check_time DESC)
    WHERE is_deleted = false;

-- Offline sync dedup uses mobile_check_time when present and falls back to check_time.
-- Keep separate plain-column indexes to avoid non-immutable timestamp/timestamptz casts.
CREATE INDEX IF NOT EXISTS idx_attendance_records_dedup_check_time
    ON attendance_records (employee_id, type, check_time)
    WHERE is_deleted = false AND is_valid = true;

-- Monitoring/debug queries for disputed recognition results by employee/date/result.
CREATE INDEX IF NOT EXISTS idx_face_recognition_logs_employee_outcome_time
    ON face_recognition_logs (employee_id, outcome, occurred_at DESC)
    WHERE is_deleted = false;
