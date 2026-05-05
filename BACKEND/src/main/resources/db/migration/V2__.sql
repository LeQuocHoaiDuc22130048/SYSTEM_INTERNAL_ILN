CREATE TABLE refresh_tokens
(
    id          UUID         NOT NULL,
    user_id     UUID         NOT NULL,
    token_hash  VARCHAR(255) NOT NULL,
    expires_at  TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    is_revoked  BOOLEAN      NOT NULL,
    device_info VARCHAR(255),
    created_at  TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    CONSTRAINT pk_refresh_tokens PRIMARY KEY (id)
);

ALTER TABLE refresh_tokens
    ADD CONSTRAINT uc_refresh_tokens_token_hash UNIQUE (token_hash);