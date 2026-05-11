CREATE TABLE board_items
(
    id          UUID                        NOT NULL,
    created_at  TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    updated_at  TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    created_by  UUID,
    updated_by  UUID,
    is_deleted  BOOLEAN                     NOT NULL,
    deleted_at  TIMESTAMP WITHOUT TIME ZONE,
    qr_code     VARCHAR(100)                NOT NULL,
    name        VARCHAR(200)                NOT NULL,
    category    VARCHAR(100),
    description TEXT,
    status      VARCHAR(20)                 NOT NULL,
    location    VARCHAR(100),
    CONSTRAINT pk_board_items PRIMARY KEY (id)
);

ALTER TABLE board_items
    ADD CONSTRAINT uc_board_items_qr_code UNIQUE (qr_code);