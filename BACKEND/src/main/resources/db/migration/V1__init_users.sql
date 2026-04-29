-- ============================================================
-- V1: Khởi tạo bảng users và user_registration_requests
-- ============================================================

-- Enum types
CREATE TYPE user_role AS ENUM ('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'EMPLOYEE');
CREATE TYPE user_status AS ENUM ('REGISTERED', 'PENDING_APPROVAL', 'ACTIVE', 'SUSPENDED', 'DELETED');

-- Bảng users
CREATE TABLE IF NOT EXISTS users
(
    id               UUID PRIMARY KEY         DEFAULT gen_random_uuid(),

    -- Thông tin đăng nhập
    username         VARCHAR(50)     NOT NULL UNIQUE,
    email            VARCHAR(150)    NOT NULL UNIQUE,
    password_hash    VARCHAR(255)    NOT NULL,

    -- Thông tin cá nhân (bắt buộc)
    full_name        VARCHAR(100)    NOT NULL,
    employee_code    VARCHAR(30)     UNIQUE,            -- Format: {DeptCode}-{YYYY}-{NNN}
    department       VARCHAR(100),
    phone            VARCHAR(20),

    -- Thông tin cá nhân (tùy chọn - mã hóa AES-256)
    national_id      VARCHAR(500),                      -- CCCD (encrypted)
    date_of_birth    DATE,
    address          TEXT,

    -- Phân quyền & trạng thái
    role             user_role       NOT NULL DEFAULT 'EMPLOYEE',
    status           user_status     NOT NULL DEFAULT 'PENDING_APPROVAL',

    -- Xác nhận tài khoản
    approved_by      UUID REFERENCES users (id),
    approved_at      TIMESTAMP,
    rejection_reason TEXT,

    -- Chấm công
    face_encoding    TEXT,                              -- JSON vector (không lưu ảnh gốc)
    face_enrolled    BOOLEAN         NOT NULL DEFAULT FALSE,
    face_verified_by UUID REFERENCES users (id),

    -- Thông báo
    device_token     VARCHAR(500),                      -- Firebase FCM token
    avatar_url       VARCHAR(500),

    -- Audit columns (bắt buộc theo DB rules)
    created_at       TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP       NOT NULL DEFAULT NOW(),
    created_by       UUID,                              -- NULL cho account đầu tiên (seed)
    updated_by       UUID REFERENCES users (id),
    is_deleted       BOOLEAN         NOT NULL DEFAULT FALSE,
    deleted_at       TIMESTAMP
    );

-- Indexes
CREATE INDEX idx_users_username   ON users (username) WHERE is_deleted = FALSE;
CREATE INDEX idx_users_email      ON users (email) WHERE is_deleted = FALSE;
CREATE INDEX idx_users_role       ON users (role) WHERE is_deleted = FALSE;
CREATE INDEX idx_users_status     ON users (status) WHERE is_deleted = FALSE;
CREATE INDEX idx_users_emp_code   ON users (employee_code) WHERE is_deleted = FALSE;

-- Bảng lịch sử duyệt tài khoản
CREATE TABLE IF NOT EXISTS user_registration_requests
(
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID         NOT NULL REFERENCES users (id),
    action       VARCHAR(20)  NOT NULL CHECK (action IN ('APPROVE', 'REJECT')),
    reviewed_by  UUID         NOT NULL REFERENCES users (id),
    note         TEXT,
    reviewed_at  TIMESTAMP    NOT NULL DEFAULT NOW(),

    -- Audit
    created_at   TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMP    NOT NULL DEFAULT NOW(),
    created_by   UUID REFERENCES users (id),
    updated_by   UUID REFERENCES users (id),
    is_deleted   BOOLEAN      NOT NULL DEFAULT FALSE,
    deleted_at   TIMESTAMP
    );

CREATE INDEX idx_reg_requests_user ON user_registration_requests (user_id);

-- Bảng refresh tokens (lưu để hỗ trợ revoke)
CREATE TABLE IF NOT EXISTS refresh_tokens
(
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash  VARCHAR(255) NOT NULL UNIQUE,           -- Hash của refresh token
    expires_at  TIMESTAMP   NOT NULL,
    is_revoked  BOOLEAN     NOT NULL DEFAULT FALSE,
    device_info VARCHAR(255),                           -- Thông tin thiết bị
    created_at  TIMESTAMP   NOT NULL DEFAULT NOW()
    );

CREATE INDEX idx_refresh_tokens_user    ON refresh_tokens (user_id);
CREATE INDEX idx_refresh_tokens_hash    ON refresh_tokens (token_hash) WHERE is_revoked = FALSE;

-- Seed tài khoản SUPER_ADMIN mặc định
-- Password: Admin@123456 (BCrypt strength 12)
INSERT INTO users (id, username, email, password_hash, full_name, role, status, created_at, updated_at, is_deleted)
VALUES (
           gen_random_uuid(),
           'superadmin',
           'superadmin@company.com',
           '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4J/Gu5TQ0e',
           'Super Administrator',
           'SUPER_ADMIN',
           'ACTIVE',
           NOW(),
           NOW(),
           FALSE
       );

ALTER TABLE users
ALTER COLUMN date_of_birth
TYPE TIMESTAMPTZ
USING date_of_birth::timestamp with time zone;