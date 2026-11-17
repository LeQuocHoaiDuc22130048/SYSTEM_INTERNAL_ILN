-- V82: Multi-device Repair Quotations & Payment Proofs (Option 1: 1 Quotation - N RepairOrders)

-- 1. Add bank transfer / VietQR fields to portal_support_configs
ALTER TABLE portal_support_configs
    ADD COLUMN IF NOT EXISTS bank_name VARCHAR(150) NOT NULL DEFAULT 'MB Bank (Quân Đội)',
    ADD COLUMN IF NOT EXISTS bank_bin VARCHAR(20) NOT NULL DEFAULT '970422',
    ADD COLUMN IF NOT EXISTS bank_account_number VARCHAR(50) NOT NULL DEFAULT '9964266771',
    ADD COLUMN IF NOT EXISTS bank_account_holder VARCHAR(200) NOT NULL DEFAULT 'CONG TY TNHH KY THUAT CONG NGHE';

-- 2. Add quotation management permission
INSERT INTO permissions (code, module, name, description, assignable)
VALUES
    ('REPAIR_QUOTATION_MANAGE', 'REPAIR', 'Quản lý báo giá sửa chữa', 'Tạo, gửi báo giá và đối soát chứng từ thanh toán', TRUE)
ON CONFLICT (code) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.code IN ('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'TECHNICIAN')
  AND p.code = 'REPAIR_QUOTATION_MANAGE'
ON CONFLICT DO NOTHING;

-- 3. repair_quotations
CREATE TABLE IF NOT EXISTS repair_quotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quote_code VARCHAR(30) NOT NULL UNIQUE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    customer_name VARCHAR(150) NOT NULL,
    customer_phone VARCHAR(30),
    title VARCHAR(250),
    note TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
    total_estimated_amount NUMERIC(15, 2) NOT NULL DEFAULT 0,
    total_approved_amount NUMERIC(15, 2) NOT NULL DEFAULT 0,
    sent_at TIMESTAMP WITH TIME ZONE,
    responded_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_repair_quotations_customer_status
    ON repair_quotations (customer_id, status)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_repair_quotations_created_at
    ON repair_quotations (created_at DESC)
    WHERE is_deleted = FALSE;

-- 4. repair_quotation_items (each item links 1-to-1 to a RepairOrder inside the quotation)
CREATE TABLE IF NOT EXISTS repair_quotation_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quotation_id UUID NOT NULL REFERENCES repair_quotations(id) ON DELETE CASCADE,
    repair_order_id UUID NOT NULL REFERENCES repair_orders(id) ON DELETE RESTRICT,
    order_code VARCHAR(30) NOT NULL,
    device_name VARCHAR(200) NOT NULL,
    device_type VARCHAR(100),
    serial_number VARCHAR(100),
    diagnosed_errors_json TEXT,
    base_cost NUMERIC(15, 2) NOT NULL DEFAULT 0,
    warranty_options_json TEXT,
    selected_warranty_code VARCHAR(50),
    selected_warranty_label VARCHAR(150),
    warranty_fee NUMERIC(15, 2) NOT NULL DEFAULT 0,
    final_amount NUMERIC(15, 2) NOT NULL DEFAULT 0,
    decision VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    reject_reason TEXT,
    decided_at TIMESTAMP WITH TIME ZONE,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_repair_quotation_items_quotation
    ON repair_quotation_items (quotation_id, sort_order)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_repair_quotation_items_order
    ON repair_quotation_items (repair_order_id)
    WHERE is_deleted = FALSE;

-- 5. repair_quotation_line_items
CREATE TABLE IF NOT EXISTS repair_quotation_line_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quotation_item_id UUID NOT NULL REFERENCES repair_quotation_items(id) ON DELETE CASCADE,
    description VARCHAR(300) NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    unit_price NUMERIC(15, 2) NOT NULL DEFAULT 0,
    amount NUMERIC(15, 2) NOT NULL DEFAULT 0,
    sort_order INT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_repair_quotation_line_items_item
    ON repair_quotation_line_items (quotation_item_id, sort_order);

-- 6. repair_payment_proofs
CREATE TABLE IF NOT EXISTS repair_payment_proofs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quotation_id UUID NOT NULL REFERENCES repair_quotations(id) ON DELETE CASCADE,
    amount NUMERIC(15, 2) NOT NULL,
    transfer_content VARCHAR(200) NOT NULL,
    proof_file_url VARCHAR(500) NOT NULL,
    proof_file_name VARCHAR(255),
    note TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING_VERIFY',
    verified_by UUID,
    verified_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_repair_payment_proofs_quotation
    ON repair_payment_proofs (quotation_id, created_at DESC)
    WHERE is_deleted = FALSE;

