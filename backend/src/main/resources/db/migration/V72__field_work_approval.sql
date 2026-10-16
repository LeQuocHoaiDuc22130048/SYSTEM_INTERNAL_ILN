ALTER TABLE field_work_days ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'APPROVED';
ALTER TABLE field_work_days ADD COLUMN reviewed_by UUID;
ALTER TABLE field_work_days ADD COLUMN reviewed_at TIMESTAMPTZ;
ALTER TABLE field_work_days ADD COLUMN version BIGINT NOT NULL DEFAULT 0;
ALTER TABLE field_work_days ADD CONSTRAINT ck_field_work_status CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED'));
CREATE INDEX idx_field_work_pending ON field_work_days(status, created_at) WHERE is_deleted = FALSE;
ALTER TABLE field_work_days ALTER COLUMN status SET DEFAULT 'PENDING';
