-- V55__full_db_architecture_alignment.sql
-- Nâng cấp và đồng bộ 100% cấu trúc Database theo tài liệu đặc tả kiến trúc docs/database-architecture-current.md

-- 1. Tạo bảng suppliers (Nhà cung cấp linh kiện)
CREATE TABLE IF NOT EXISTS suppliers (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code          VARCHAR(50) NOT NULL UNIQUE,
    name          VARCHAR(150) NOT NULL,
    contact_info  TEXT,
    website_link  VARCHAR(255),
    created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by    UUID REFERENCES users (id),
    updated_by    UUID REFERENCES users (id),
    is_deleted    BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at    TIMESTAMP
);

-- 2. Cập nhật bảng categories: Bổ sung cột code
ALTER TABLE categories
    ADD COLUMN IF NOT EXISTS code VARCHAR(50);

UPDATE categories
SET code = 'CAT-' || UPPER(RIGHT(id::text, 12))
WHERE code IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uc_categories_code
    ON categories (code)
    WHERE is_deleted = FALSE AND code IS NOT NULL;

-- 3. Cập nhật bảng manufacturers: Bổ sung cột code và website
ALTER TABLE manufacturers
    ADD COLUMN IF NOT EXISTS code VARCHAR(50),
    ADD COLUMN IF NOT EXISTS website VARCHAR(255);

UPDATE manufacturers
SET code = 'MFG-' || UPPER(RIGHT(id::text, 12))
WHERE code IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uc_manufacturers_code
    ON manufacturers (code)
    WHERE is_deleted = FALSE AND code IS NOT NULL;

-- 4. Cập nhật bảng parts: Bổ sung sku, series, footprint, measurement_unit, replacement_part_ids, replacement_condition
ALTER TABLE parts
    ADD COLUMN IF NOT EXISTS sku VARCHAR(100),
    ADD COLUMN IF NOT EXISTS series VARCHAR(100),
    ADD COLUMN IF NOT EXISTS footprint VARCHAR(50),
    ADD COLUMN IF NOT EXISTS measurement_unit VARCHAR(20) DEFAULT 'Cái',
    ADD COLUMN IF NOT EXISTS replacement_part_ids UUID[],
    ADD COLUMN IF NOT EXISTS replacement_condition TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS uc_parts_sku
    ON parts (sku)
    WHERE is_deleted = FALSE AND sku IS NOT NULL;

-- 5. Cập nhật bảng part_lots: Bổ sung supplier_id và purchase_link
ALTER TABLE part_lots
    ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES suppliers (id),
    ADD COLUMN IF NOT EXISTS purchase_link VARCHAR(255);

-- 6. Cập nhật bảng board_items: Bổ sung repair_brand
ALTER TABLE board_items
    ADD COLUMN IF NOT EXISTS repair_brand VARCHAR(100);
