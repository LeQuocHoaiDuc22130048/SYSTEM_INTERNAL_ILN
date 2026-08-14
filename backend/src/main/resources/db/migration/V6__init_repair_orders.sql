CREATE TABLE repair_orders
(
    id             UUID         NOT NULL,
    created_at     TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    updated_at     TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    created_by     UUID,
    updated_by     UUID,
    is_deleted     BOOLEAN      NOT NULL,
    deleted_at     TIMESTAMP WITHOUT TIME ZONE,
    order_code     VARCHAR(30)  NOT NULL,
    device_name    VARCHAR(200) NOT NULL,
    device_type    VARCHAR(100),
    customer_name  VARCHAR(100) NOT NULL,
    customer_phone VARCHAR(20)  NOT NULL,
    description    TEXT         NOT NULL,
    status         VARCHAR(20)  NOT NULL,
    priority       INTEGER      NOT NULL,
    received_by    UUID         NOT NULL,
    assigned_to    UUID,
    received_at    TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    estimated_done TIMESTAMP WITHOUT TIME ZONE,
    started_at     TIMESTAMP WITHOUT TIME ZONE,
    completed_at   TIMESTAMP WITHOUT TIME ZONE,
    delivered_at   TIMESTAMP WITHOUT TIME ZONE,
    CONSTRAINT pk_repair_orders PRIMARY KEY (id)
);

ALTER TABLE repair_orders
    ADD CONSTRAINT uc_repair_orders_order_code UNIQUE (order_code);