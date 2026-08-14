CREATE TABLE work_schedules
(
    id          UUID    NOT NULL,
    created_at  TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    updated_at  TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    created_by  UUID,
    updated_by  UUID,
    is_deleted  BOOLEAN NOT NULL,
    deleted_at  TIMESTAMP WITHOUT TIME ZONE,
    employee_id UUID    NOT NULL,
    work_date   date    NOT NULL,
    shift_start time WITHOUT TIME ZONE      NOT NULL,
    shift_end   time WITHOUT TIME ZONE      NOT NULL,
    note        TEXT,
    CONSTRAINT pk_work_schedules PRIMARY KEY (id)
);

ALTER TABLE work_schedules
    ADD CONSTRAINT uc_206e2d1c5e9b4f3335cd434bc UNIQUE (employee_id, work_date);