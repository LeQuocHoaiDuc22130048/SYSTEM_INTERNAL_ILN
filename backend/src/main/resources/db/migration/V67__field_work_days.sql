CREATE TABLE field_work_days (
    id UUID NOT NULL PRIMARY KEY,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    created_by UUID,
    updated_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITHOUT TIME ZONE,
    employee_id UUID NOT NULL REFERENCES users(id),
    work_date DATE NOT NULL,
    note VARCHAR(2000) NOT NULL CHECK (length(trim(note)) > 0),
    CONSTRAINT uq_field_work_employee_date UNIQUE (employee_id, work_date)
);
CREATE INDEX idx_field_work_active_date ON field_work_days(work_date, employee_id)
    WHERE is_deleted = FALSE;
