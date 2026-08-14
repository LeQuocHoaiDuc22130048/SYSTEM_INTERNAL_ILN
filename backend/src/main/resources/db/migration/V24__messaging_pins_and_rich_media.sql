ALTER TABLE conversation_members
    ADD COLUMN IF NOT EXISTS pinned_at TIMESTAMPTZ;

ALTER TABLE conversations
    ADD COLUMN IF NOT EXISTS pinned_message_id UUID REFERENCES messages(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS pinned_message_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS pinned_message_by UUID REFERENCES users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_conversation_members_user_pinned
    ON conversation_members(user_id, pinned_at DESC);

CREATE INDEX IF NOT EXISTS idx_conversations_pinned_message
    ON conversations(pinned_message_id);
