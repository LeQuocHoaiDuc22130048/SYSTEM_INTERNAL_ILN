CREATE TABLE conversation_members
(
    conversation_id UUID    NOT NULL,
    user_id         UUID    NOT NULL,
    joined_at       TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    last_read_at    TIMESTAMP WITHOUT TIME ZONE,
    is_admin        BOOLEAN NOT NULL,
    CONSTRAINT pk_conversation_members PRIMARY KEY (conversation_id, user_id),
    CONSTRAINT fk_conversation_members_conversation FOREIGN KEY (conversation_id) REFERENCES conversations (id),
    CONSTRAINT fk_conversation_members_user FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE INDEX idx_conversation_members_user
    ON conversation_members (user_id);
