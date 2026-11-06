-- V77: Customer Feedbacks and Service Ratings
CREATE TABLE IF NOT EXISTS customer_feedbacks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_code VARCHAR(100),
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    customer_name VARCHAR(255) NOT NULL,
    customer_phone VARCHAR(50),
    customer_code VARCHAR(50),
    device_model VARCHAR(255),
    rating INT NOT NULL DEFAULT 5,
    type VARCHAR(50) NOT NULL DEFAULT 'SERVICE_QUALITY',
    type_name VARCHAR(100) NOT NULL DEFAULT 'Đánh giá chất lượng',
    tags TEXT,
    content TEXT NOT NULL,
    images TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
    status_name VARCHAR(100) NOT NULL DEFAULT 'Chờ tiếp nhận',
    reply TEXT,
    reply_at TIMESTAMP WITH TIME ZONE,
    replied_by VARCHAR(255),
    is_urgent BOOLEAN NOT NULL DEFAULT FALSE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID
);

CREATE INDEX IF NOT EXISTS idx_customer_feedbacks_status ON customer_feedbacks (status, is_urgent, is_deleted);
CREATE INDEX IF NOT EXISTS idx_customer_feedbacks_customer_id ON customer_feedbacks (customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_feedbacks_created_at ON customer_feedbacks (created_at DESC);

