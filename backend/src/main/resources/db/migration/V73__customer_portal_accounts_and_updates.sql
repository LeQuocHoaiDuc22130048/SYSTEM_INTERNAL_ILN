-- V73: Customer Portal accounts, invitations, published updates and published media

-- 1. Add CUSTOMER to user_role enum
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'CUSTOMER';

-- 2. Add CUSTOMER role to roles table
INSERT INTO roles (code, name, description, system_role)
VALUES ('CUSTOMER', 'Khách hàng', 'Tài khoản khách hàng theo dõi đơn sửa chữa', TRUE)
ON CONFLICT (code) DO NOTHING;

-- 3. Add permissions
INSERT INTO permissions (code, module, name, description, assignable)
VALUES 
    ('CUSTOMER_PORTAL_VIEW', 'PORTAL', 'Xem cổng khách hàng', 'Xem danh sách và chi tiết đơn hàng của chính mình', TRUE),
    ('CUSTOMER_ACCOUNT_MANAGE', 'CUSTOMER', 'Quản lý tài khoản khách hàng', 'Tạo tài khoản, đổi mật khẩu và khóa tài khoản khách hàng', TRUE),
    ('REPAIR_CUSTOMER_PUBLISH', 'REPAIR', 'Công bố thông tin cho khách', 'Công bố cập nhật tiến độ hoặc ảnh cho khách hàng', TRUE)
ON CONFLICT (code) DO NOTHING;

-- 4. Role permissions mapping
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.code = 'CUSTOMER' AND p.code = 'CUSTOMER_PORTAL_VIEW'
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.code IN ('SUPER_ADMIN', 'ADMIN', 'MANAGER') 
  AND p.code = 'CUSTOMER_ACCOUNT_MANAGE'
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.code IN ('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'TECHNICIAN') 
  AND p.code = 'REPAIR_CUSTOMER_PUBLISH'
ON CONFLICT DO NOTHING;

-- 5. customer_accounts
CREATE TABLE IF NOT EXISTS customer_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    contact_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(254),
    is_primary BOOLEAN NOT NULL DEFAULT TRUE,
    must_change_password BOOLEAN NOT NULL DEFAULT FALSE,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT uq_customer_accounts_user UNIQUE (user_id)
);
CREATE INDEX IF NOT EXISTS idx_customer_accounts_cust ON customer_accounts (customer_id) WHERE active = TRUE AND is_deleted = FALSE;

-- 6. customer_invitations
CREATE TABLE IF NOT EXISTS customer_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    contact_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(254),
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    consumed_at TIMESTAMP WITH TIME ZONE,
    revoked_at TIMESTAMP WITH TIME ZONE,
    created_by UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_customer_invitations_token ON customer_invitations(token_hash) WHERE consumed_at IS NULL AND revoked_at IS NULL;

-- 7. repair_customer_updates
CREATE TABLE IF NOT EXISTS repair_customer_updates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES repair_orders(id) ON DELETE CASCADE,
    device_id UUID REFERENCES repair_devices(id) ON DELETE SET NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    status_at_time VARCHAR(20),
    published_by UUID NOT NULL,
    published_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE
);
CREATE INDEX IF NOT EXISTS idx_repair_customer_updates_order ON repair_customer_updates(order_id, published_at DESC) WHERE is_deleted = FALSE;

-- 8. repair_customer_media
CREATE TABLE IF NOT EXISTS repair_customer_media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES repair_orders(id) ON DELETE CASCADE,
    media_id UUID NOT NULL REFERENCES repair_images(id) ON DELETE CASCADE,
    caption VARCHAR(255),
    published_by UUID NOT NULL,
    published_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT uq_repair_customer_media UNIQUE (order_id, media_id)
);
CREATE INDEX IF NOT EXISTS idx_repair_customer_media_order ON repair_customer_media(order_id) WHERE is_deleted = FALSE;
