CREATE TABLE app_updates
(
    id            UUID         NOT NULL,
    created_at    TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    updated_at    TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    created_by    UUID,
    updated_by    UUID,
    is_deleted    BOOLEAN      NOT NULL DEFAULT FALSE,
    deleted_at    TIMESTAMP WITHOUT TIME ZONE,
    version       VARCHAR(50)  NOT NULL,
    changelog     TEXT         NOT NULL,
    download_url  VARCHAR(500) NOT NULL,
    mandatory     BOOLEAN      NOT NULL DEFAULT FALSE,
    status        VARCHAR(20)  NOT NULL DEFAULT 'DRAFT',
    released_at   TIMESTAMP WITHOUT TIME ZONE,
    CONSTRAINT pk_app_updates PRIMARY KEY (id)
);
