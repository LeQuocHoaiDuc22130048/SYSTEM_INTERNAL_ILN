-- V53__align_warehouse_architecture_spec.sql
-- Cập nhật cấu trúc database module Warehouse khớp với docs/database-architecture-current.md

-- 1. Đảm bảo bảng stock_movements tồn tại
CREATE TABLE IF NOT EXISTS stock_movements (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    part_id          UUID REFERENCES parts (id),
    part_lot_id      UUID REFERENCES part_lots (id),
    board_item_id    UUID REFERENCES board_items (id),
    movement_type    VARCHAR(30) NOT NULL,
    quantity         NUMERIC(18, 4) NOT NULL DEFAULT 1,
    from_location_id UUID REFERENCES store_locations (id),
    to_location_id   UUID REFERENCES store_locations (id),
    ref_type         VARCHAR(50),
    ref_id           UUID,
    note             TEXT,
    created_at       TIMESTAMP   NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP   NOT NULL DEFAULT NOW(),
    created_by       UUID REFERENCES users (id),
    updated_by       UUID REFERENCES users (id),
    is_deleted       BOOLEAN     NOT NULL DEFAULT FALSE,
    deleted_at       TIMESTAMP
);

-- 2. Bổ sung các cột tiêu chuẩn cho bảng stock_movements (Append-Only Single Source of Truth)
ALTER TABLE stock_movements
    ADD COLUMN IF NOT EXISTS movement_code VARCHAR(50),
    ADD COLUMN IF NOT EXISTS storage_location_id UUID REFERENCES store_locations (id),
    ADD COLUMN IF NOT EXISTS amount NUMERIC(18, 4) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS remaining_to_return NUMERIC(18, 4) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS movement_status VARCHAR(20) DEFAULT 'COMPLETED',
    ADD COLUMN IF NOT EXISTS parent_movement_id UUID REFERENCES stock_movements (id),
    ADD COLUMN IF NOT EXISTS purpose TEXT;

-- Tự động sinh mã biến động kho (movement_code) cho dữ liệu cũ nếu bị null
UPDATE stock_movements
SET movement_code = 'SM-' || SUBSTRING(id::text, 1, 8)
WHERE movement_code IS NULL;

-- 3. Chỉ mục tối ưu hóa cho stock_movements
CREATE UNIQUE INDEX IF NOT EXISTS uc_stock_movements_movement_code
    ON stock_movements (movement_code)
    WHERE movement_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_stock_movements_query ON stock_movements (part_id, created_at);
CREATE INDEX IF NOT EXISTS idx_stock_movements_parent ON stock_movements (parent_movement_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_user ON stock_movements (created_by);
CREATE INDEX IF NOT EXISTS idx_stock_movements_status_open ON stock_movements (movement_status) WHERE movement_status IN ('OPEN', 'PARTIAL_RETURNED');

-- 4. Bổ sung chỉ mục truy vấn tồn kho theo cặp (part_id, store_location_id) trên part_lots
CREATE INDEX IF NOT EXISTS idx_part_lots_part_loc ON part_lots (part_id, store_location_id);

-- 5. Bổ sung chỉ mục truy vấn vị trí theo QR Code trên store_locations
CREATE INDEX IF NOT EXISTS idx_store_locations_qr_code_lookup ON store_locations (qr_code) WHERE qr_code IS NOT NULL;
