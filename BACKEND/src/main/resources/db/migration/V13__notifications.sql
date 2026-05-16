ALTER TABLE notifications
    ADD CONSTRAINT fk_notifications_recipient
        FOREIGN KEY (recipient_id) REFERENCES users (id);

CREATE INDEX idx_notifications_recipient
    ON notifications (recipient_id, is_read, created_at DESC);

CREATE INDEX idx_notifications_unread
    ON notifications (recipient_id)
    WHERE is_read = FALSE AND is_deleted = FALSE;
