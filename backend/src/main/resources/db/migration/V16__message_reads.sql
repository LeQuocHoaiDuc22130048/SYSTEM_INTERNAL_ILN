CREATE TABLE message_reads
(
    message_id UUID NOT NULL,
    user_id    UUID NOT NULL,
    read_at    TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    CONSTRAINT pk_message_reads PRIMARY KEY (message_id, user_id),
    CONSTRAINT fk_message_reads_message FOREIGN KEY (message_id) REFERENCES messages (id) ON DELETE CASCADE,
    CONSTRAINT fk_message_reads_user FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE INDEX idx_message_reads_user
    ON message_reads (user_id);
