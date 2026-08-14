-- ── V44: User-level permission overrides ─────────────────────────────────
-- Cho phép cấp thêm (granted=TRUE) hoặc thu hồi (granted=FALSE) quyền
-- riêng cho từng user, bất kể role của họ là gì.

CREATE TABLE IF NOT EXISTS user_permissions
(
    user_id       UUID      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    permission_id UUID      NOT NULL REFERENCES permissions (id) ON DELETE CASCADE,
    granted       BOOLEAN   NOT NULL DEFAULT TRUE,  -- TRUE = thêm quyền, FALSE = thu hồi
    granted_by    UUID      REFERENCES users (id) ON DELETE SET NULL,
    granted_at    TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, permission_id)
);

CREATE INDEX IF NOT EXISTS idx_user_permissions_user_id       ON user_permissions (user_id);
CREATE INDEX IF NOT EXISTS idx_user_permissions_permission_id ON user_permissions (permission_id);
CREATE INDEX IF NOT EXISTS idx_user_permissions_granted_by    ON user_permissions (granted_by);
