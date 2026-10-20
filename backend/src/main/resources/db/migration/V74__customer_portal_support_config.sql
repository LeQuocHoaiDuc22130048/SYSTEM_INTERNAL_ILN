-- V74: Customer portal support contact configuration (Hotline, Zalo, working hours)
CREATE TABLE IF NOT EXISTS portal_support_configs (
    id UUID PRIMARY KEY,
    hotline_number VARCHAR(50) NOT NULL DEFAULT '0909000000',
    hotline_label VARCHAR(100) NOT NULL DEFAULT 'Hotline Kỹ Thuật',
    zalo_url VARCHAR(255) NOT NULL DEFAULT 'https://zalo.me',
    zalo_label VARCHAR(100) NOT NULL DEFAULT 'Chat Zalo Tiếp Nhận',
    working_hours VARCHAR(200) NOT NULL DEFAULT '08:00 - 17:30 (Thứ 2 - Thứ 7)',
    workshop_address VARCHAR(500) NOT NULL DEFAULT 'Trung tâm kỹ thuật sửa chữa thiết bị công nghiệp',
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID
);

INSERT INTO portal_support_configs (
    id,
    hotline_number,
    hotline_label,
    zalo_url,
    zalo_label,
    working_hours,
    workshop_address,
    updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    '0909000000',
    'Hotline Kỹ Thuật',
    'https://zalo.me',
    'Chat Zalo Tiếp Nhận',
    '08:00 - 17:30 (Thứ 2 - Thứ 7)',
    'Trung tâm kỹ thuật sửa chữa thiết bị công nghiệp',
    CURRENT_TIMESTAMP
) ON CONFLICT (id) DO NOTHING;
