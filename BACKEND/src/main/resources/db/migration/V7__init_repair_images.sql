CREATE TABLE repair_images
(
    id          UUID         NOT NULL,
    created_at  TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    updated_at  TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    created_by  UUID,
    updated_by  UUID,
    is_deleted  BOOLEAN      NOT NULL,
    deleted_at  TIMESTAMP WITHOUT TIME ZONE,
    order_id    UUID         NOT NULL,
    image_url   VARCHAR(500) NOT NULL,
    caption     VARCHAR(255),
    uploaded_by UUID         NOT NULL,
    uploaded_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    CONSTRAINT pk_repair_images PRIMARY KEY (id)
);