CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE user_role AS ENUM ('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'EMPLOYEE');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_status') THEN
        CREATE TYPE user_status AS ENUM ('REGISTERED', 'PENDING_APPROVAL', 'ACTIVE', 'SUSPENDED', 'DELETED');
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS users
(
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username         VARCHAR(50)  NOT NULL UNIQUE,
    password_hash    VARCHAR(255) NOT NULL,
    full_name        VARCHAR(100) NOT NULL,
    employee_code    VARCHAR(30) UNIQUE,
    department       VARCHAR(100),
    phone            VARCHAR(20),
    national_id      VARCHAR(500),
    date_of_birth    DATE,
    address          TEXT,
    role             user_role    NOT NULL DEFAULT 'EMPLOYEE',
    status           user_status  NOT NULL DEFAULT 'PENDING_APPROVAL',
    approved_by      UUID REFERENCES users (id),
    approved_at      TIMESTAMP,
    rejection_reason TEXT,
    face_encoding    TEXT,
    face_enrolled    BOOLEAN      NOT NULL DEFAULT FALSE,
    face_verified_by UUID REFERENCES users (id),
    device_token     VARCHAR(500),
    avatar_url       VARCHAR(500),
    created_at       TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP    NOT NULL DEFAULT NOW(),
    created_by       UUID,
    updated_by       UUID REFERENCES users (id),
    is_deleted       BOOLEAN      NOT NULL DEFAULT FALSE,
    deleted_at       TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_username ON users (username) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_users_role ON users (role) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_users_status ON users (status) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_users_emp_code ON users (employee_code) WHERE is_deleted = FALSE;
