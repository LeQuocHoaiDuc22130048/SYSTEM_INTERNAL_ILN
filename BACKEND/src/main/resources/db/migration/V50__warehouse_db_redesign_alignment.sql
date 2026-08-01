-- Migration V50: Align warehouse module tables with updated database architecture specification

-- 1. Align board_items table
ALTER TABLE board_items
    ADD COLUMN IF NOT EXISTS model VARCHAR(100),
    ADD COLUMN IF NOT EXISTS board_type VARCHAR(100),
    ADD COLUMN IF NOT EXISTS firmware VARCHAR(50),
    ADD COLUMN IF NOT EXISTS removed_parts JSONB,
    ADD COLUMN IF NOT EXISTS received_date DATE,
    ADD COLUMN IF NOT EXISTS note TEXT;

CREATE INDEX IF NOT EXISTS idx_board_items_model ON board_items (model);
CREATE INDEX IF NOT EXISTS idx_board_items_board_type ON board_items (board_type);

-- 2. Align part_lots table
ALTER TABLE part_lots
    ADD COLUMN IF NOT EXISTS origin VARCHAR(50),
    ADD COLUMN IF NOT EXISTS condition VARCHAR(50),
    ADD COLUMN IF NOT EXISTS received_date DATE;

-- 3. Align parts table
ALTER TABLE parts
    ADD COLUMN IF NOT EXISTS max_amount NUMERIC(18, 4) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS purchase_price NUMERIC(15, 2),
    ADD COLUMN IF NOT EXISTS sale_price NUMERIC(15, 2),
    ADD COLUMN IF NOT EXISTS parameters JSONB,
    ADD COLUMN IF NOT EXISTS datasheet_url TEXT,
    ADD COLUMN IF NOT EXISTS image_url TEXT,
    ADD COLUMN IF NOT EXISTS note TEXT;

-- 4. Align store_locations table
ALTER TABLE store_locations
    ADD COLUMN IF NOT EXISTS qr_code TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS uc_store_locations_qr_code
    ON store_locations (qr_code)
    WHERE qr_code IS NOT NULL;
