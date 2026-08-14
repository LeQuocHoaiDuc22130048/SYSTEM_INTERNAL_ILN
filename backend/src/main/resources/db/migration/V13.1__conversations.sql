CREATE TABLE conversations
(
    id         UUID                     NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    created_by UUID,
    updated_by UUID,
    is_deleted BOOLEAN                  NOT NULL,
    deleted_at TIMESTAMP WITHOUT TIME ZONE,
    type       VARCHAR(10)              NOT NULL,
    name       VARCHAR(100),
    avatar_url VARCHAR(500),
    CONSTRAINT pk_conversations PRIMARY KEY (id)
);

CREATE INDEX idx_conversations_updated_at
    ON conversations (updated_at DESC);
