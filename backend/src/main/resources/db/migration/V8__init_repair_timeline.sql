CREATE TABLE repair_timeline
(
    id           UUID         NOT NULL,
    order_id     UUID         NOT NULL,
    action       VARCHAR(100) NOT NULL,
    note         TEXT,
    performed_by UUID         NOT NULL,
    created_at   TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    created_by   UUID,
    CONSTRAINT pk_repair_timeline PRIMARY KEY (id)
);