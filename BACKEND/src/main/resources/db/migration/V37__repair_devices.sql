-- V37: Tạo bảng repair_devices và migrate dữ liệu từ repair_orders

CREATE TABLE repair_devices (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id        UUID        NOT NULL REFERENCES repair_orders(id) ON DELETE CASCADE,
    device_name     VARCHAR(200) NOT NULL,
    device_type     VARCHAR(100),
    serial_number   VARCHAR(100),
    under_warranty  BOOLEAN     NOT NULL DEFAULT FALSE,
    description     TEXT,
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    assigned_to     UUID,
    priority        INT         NOT NULL DEFAULT 100,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ
);

CREATE INDEX idx_repair_devices_order_id ON repair_devices(order_id);

-- Migrate dữ liệu cũ: mỗi repair_order → 1 repair_device
INSERT INTO repair_devices (order_id, device_name, device_type, serial_number, under_warranty, description, status, assigned_to, priority, created_at)
SELECT
    id,
    COALESCE(device_name, 'Thiết bị'),
    device_type,
    serial_number,
    COALESCE(under_warranty, FALSE),
    description,
    status,
    assigned_to,
    priority,
    COALESCE(created_at, NOW())
FROM repair_orders
WHERE is_deleted = FALSE OR is_deleted IS NULL;
