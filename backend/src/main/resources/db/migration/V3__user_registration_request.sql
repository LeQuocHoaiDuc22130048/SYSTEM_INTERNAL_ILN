CREATE TABLE user_registration_requests
(
    id          UUID        NOT NULL,
    created_at  TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    updated_at  TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    created_by  UUID,
    updated_by  UUID,
    is_deleted  BOOLEAN     NOT NULL,
    deleted_at  TIMESTAMP WITHOUT TIME ZONE,
    user_id     UUID        NOT NULL,
    action      VARCHAR(20) NOT NULL,
    reviewed_by UUID        NOT NULL,
    note        TEXT,
    reviewed_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    CONSTRAINT pk_user_registration_requests PRIMARY KEY (id)
);