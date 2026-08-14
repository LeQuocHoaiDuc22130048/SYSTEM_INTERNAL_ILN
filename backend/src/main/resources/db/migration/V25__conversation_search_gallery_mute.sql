ALTER TABLE conversation_members
    ADD COLUMN IF NOT EXISTS notifications_muted BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_messages_conversation_content
    ON messages(conversation_id, sent_at DESC)
    WHERE content IS NOT NULL;
