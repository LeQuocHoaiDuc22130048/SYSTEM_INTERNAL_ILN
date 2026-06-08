CREATE TABLE face_recognition_logs (
    id UUID NOT NULL,
    local_attempt_id VARCHAR(160),
    employee_id UUID,
    employee_name VARCHAR(255),
    attempted_by UUID,
    device_id VARCHAR(120),
    model_name VARCHAR(80) NOT NULL,
    source VARCHAR(40) NOT NULL,
    outcome VARCHAR(30) NOT NULL,
    similarity_score DOUBLE PRECISION,
    threshold DOUBLE PRECISION,
    occurred_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_by UUID,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT pk_face_recognition_logs PRIMARY KEY (id)
);

CREATE UNIQUE INDEX ux_face_recognition_logs_mobile_attempt
    ON face_recognition_logs (local_attempt_id, source)
    WHERE local_attempt_id IS NOT NULL AND is_deleted = FALSE;

CREATE INDEX idx_face_recognition_logs_day
    ON face_recognition_logs (occurred_at, outcome)
    WHERE is_deleted = FALSE;

CREATE INDEX idx_face_recognition_logs_employee
    ON face_recognition_logs (employee_id, occurred_at)
    WHERE is_deleted = FALSE;

CREATE TABLE face_recognition_daily_alerts (
    id UUID NOT NULL,
    metric_date DATE NOT NULL,
    false_reject_rate DOUBLE PRECISION NOT NULL,
    rejected_count BIGINT NOT NULL,
    total_count BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_by UUID,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT pk_face_recognition_daily_alerts PRIMARY KEY (id)
);

CREATE UNIQUE INDEX ux_face_recognition_daily_alerts_date
    ON face_recognition_daily_alerts (metric_date)
    WHERE is_deleted = FALSE;
