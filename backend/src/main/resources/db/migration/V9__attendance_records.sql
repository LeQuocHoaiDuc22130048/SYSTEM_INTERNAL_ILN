CREATE TABLE attendance_records
(
    id               UUID       NOT NULL,
    created_at       TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    updated_at       TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    created_by       UUID,
    updated_by       UUID,
    is_deleted       BOOLEAN    NOT NULL,
    deleted_at       TIMESTAMP WITHOUT TIME ZONE,
    employee_id      UUID       NOT NULL,
    type             VARCHAR(5) NOT NULL,
    check_time       TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    face_image_path  VARCHAR(500),
    confidence_score DOUBLE PRECISION,
    device_id        VARCHAR(100),
    is_valid         BOOLEAN    NOT NULL,
    note             TEXT,
    CONSTRAINT pk_attendance_records PRIMARY KEY (id)
);