CREATE TABLE notifications
(
    id           UUID         NOT NULL,
    created_at   TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    updated_at   TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    created_by   UUID,
    updated_by   UUID,
    is_deleted   BOOLEAN      NOT NULL,
    deleted_at   TIMESTAMP WITHOUT TIME ZONE,
    recipient_id UUID         NOT NULL,
    type         VARCHAR(50)  NOT NULL,
    title        VARCHAR(200) NOT NULL,
    body         TEXT         NOT NULL,
    ref_type     VARCHAR(50),
    ref_id       VARCHAR(100),
    is_read      BOOLEAN      NOT NULL,
    CONSTRAINT pk_notifications PRIMARY KEY (id)
);