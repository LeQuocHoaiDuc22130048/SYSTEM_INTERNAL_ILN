CREATE TABLE password_reset_otps
(
    id         UUID         NOT NULL,
    user_id    UUID         NOT NULL,
    code_hash  VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    attempts   INTEGER      NOT NULL DEFAULT 0,
    used       BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    CONSTRAINT pk_password_reset_otps PRIMARY KEY (id),
    CONSTRAINT fk_password_reset_otps_user FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE INDEX idx_password_reset_otps_user_created
    ON password_reset_otps (user_id, created_at DESC);
