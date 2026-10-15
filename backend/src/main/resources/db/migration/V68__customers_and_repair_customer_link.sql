CREATE TABLE customers (
    id UUID PRIMARY KEY,
    customer_code VARCHAR(35) NOT NULL UNIQUE,
    customer_name VARCHAR(100) NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('INDIVIDUAL', 'COMPANY')),
    phone VARCHAR(20),
    email VARCHAR(254),
    address VARCHAR(500),
    tax_code VARCHAR(30),
    notes VARCHAR(2000),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE
);
CREATE INDEX idx_customers_active_created ON customers (active, created_at DESC, id DESC) WHERE is_deleted = FALSE;

ALTER TABLE repair_orders ADD COLUMN customer_id UUID REFERENCES customers(id);
CREATE INDEX idx_repair_orders_customer_received ON repair_orders (customer_id, received_at DESC, id DESC) WHERE is_deleted = FALSE;

INSERT INTO permissions (code, module, name, description)
VALUES ('CUSTOMER_VIEW', 'CUSTOMER', 'Xem khách hàng', 'Tra cứu hồ sơ khách hàng'),
       ('CUSTOMER_MANAGE', 'CUSTOMER', 'Quản lý khách hàng', 'Tạo, cập nhật và ngừng hoạt động hồ sơ khách hàng')
ON CONFLICT (code) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE p.code IN ('CUSTOMER_VIEW', 'CUSTOMER_MANAGE')
  AND r.code IN ('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'EMPLOYEE')
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE p.code = 'CUSTOMER_VIEW' AND r.code IN ('TECHNICIAN', 'WAREHOUSE')
ON CONFLICT DO NOTHING;
