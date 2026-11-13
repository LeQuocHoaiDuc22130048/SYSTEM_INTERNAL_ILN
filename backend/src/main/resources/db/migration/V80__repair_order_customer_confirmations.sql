-- V80: Customer order quotation confirmation & payment proof tracking
CREATE TABLE IF NOT EXISTS repair_order_confirmations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL UNIQUE REFERENCES repair_orders(id) ON DELETE CASCADE,
    confirmation_status VARCHAR(32) NOT NULL DEFAULT 'PENDING_CUSTOMER',
    warranty_months INT NOT NULL DEFAULT 6,
    warranty_extra_fee BIGINT NOT NULL DEFAULT 0,
    base_amount BIGINT NOT NULL DEFAULT 0,
    total_amount BIGINT NOT NULL DEFAULT 0,
    diagnosis_tags_json TEXT,
    quote_items_json TEXT,
    rejection_reason TEXT,
    payment_proof_url VARCHAR(500),
    payment_proof_file_name VARCHAR(255),
    transfer_reference VARCHAR(150),
    confirmed_by_user_id UUID,
    approved_at TIMESTAMP WITH TIME ZONE,
    rejected_at TIMESTAMP WITH TIME ZONE,
    payment_submitted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_repair_order_confirmations_order_id
    ON repair_order_confirmations(order_id) WHERE is_deleted = FALSE;

