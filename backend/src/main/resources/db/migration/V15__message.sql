CREATE TABLE messages
(
    id              UUID        NOT NULL,
    created_at      TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    updated_at      TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    created_by      UUID,
    updated_by      UUID,
    is_deleted      BOOLEAN     NOT NULL,
    deleted_at      TIMESTAMP WITHOUT TIME ZONE,
    conversation_id UUID        NOT NULL,
    sender_id       UUID        NOT NULL,
    content         TEXT,
    media_url       VARCHAR(500),
    message_type    VARCHAR(10) NOT NULL,
    sent_at         TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    CONSTRAINT pk_messages PRIMARY KEY (id),
    CONSTRAINT fk_messages_conversation FOREIGN KEY (conversation_id) REFERENCES conversations (id),
    CONSTRAINT fk_messages_sender FOREIGN KEY (sender_id) REFERENCES users (id)
);

CREATE INDEX idx_messages_conversation
    ON messages (conversation_id, sent_at DESC);

CREATE INDEX idx_messages_sender
    ON messages (sender_id);
