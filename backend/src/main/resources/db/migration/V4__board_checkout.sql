CREATE TABLE board_checkouts
(
    id              UUID    NOT NULL,
    created_at      TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    updated_at      TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    created_by      UUID,
    updated_by      UUID,
    is_deleted      BOOLEAN NOT NULL,
    deleted_at      TIMESTAMP WITHOUT TIME ZONE,
    board_item_id   UUID    NOT NULL,
    taken_by        UUID    NOT NULL,
    repair_order_id UUID,
    taken_at        TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    returned_at     TIMESTAMP WITHOUT TIME ZONE,
    notes           TEXT,
    CONSTRAINT pk_board_checkouts PRIMARY KEY (id)
);