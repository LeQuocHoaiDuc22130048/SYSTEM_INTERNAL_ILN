-- V52__part_checkouts_and_location_qr_logs.sql
-- Bảng lưu nhật ký lấy và trả linh kiện kho theo vị trí & mã QR

-- 1. Đảm bảo các bảng nền tảng của kho tồn tại đầy đủ
CREATE TABLE IF NOT EXISTS categories (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id      UUID REFERENCES categories (id),
    name           VARCHAR(200) NOT NULL,
    description    TEXT,
    not_selectable BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMP    NOT NULL DEFAULT NOW(),
    created_by     UUID REFERENCES users (id),
    updated_by     UUID REFERENCES users (id),
    is_deleted     BOOLEAN      NOT NULL DEFAULT FALSE,
    deleted_at     TIMESTAMP
);

CREATE TABLE IF NOT EXISTS store_locations (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id        UUID REFERENCES store_locations (id),
    code             VARCHAR(80)  NOT NULL UNIQUE,
    name             VARCHAR(200) NOT NULL,
    description      TEXT,
    is_full          BOOLEAN      NOT NULL DEFAULT FALSE,
    only_single_part BOOLEAN      NOT NULL DEFAULT FALSE,
    qr_code          TEXT,
    created_at       TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP    NOT NULL DEFAULT NOW(),
    created_by       UUID REFERENCES users (id),
    updated_by       UUID REFERENCES users (id),
    is_deleted       BOOLEAN      NOT NULL DEFAULT FALSE,
    deleted_at       TIMESTAMP
);

CREATE TABLE IF NOT EXISTS parts (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ipn                 VARCHAR(100) NOT NULL UNIQUE,
    name                VARCHAR(200) NOT NULL,
    description         TEXT,
    min_amount          NUMERIC(18, 4) NOT NULL DEFAULT 0,
    max_amount          NUMERIC(18, 4) DEFAULT 0,
    purchase_price      NUMERIC(15, 2),
    sale_price          NUMERIC(15, 2),
    manufacturing_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    category_id         UUID REFERENCES categories (id),
    parameters          JSONB,
    datasheet_url       TEXT,
    image_url           TEXT,
    note                TEXT,
    created_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by          UUID REFERENCES users (id),
    updated_by          UUID REFERENCES users (id),
    is_deleted          BOOLEAN   NOT NULL DEFAULT FALSE,
    deleted_at          TIMESTAMP
);

CREATE TABLE IF NOT EXISTS part_lots (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    part_id          UUID NOT NULL REFERENCES parts (id),
    store_location_id UUID REFERENCES store_locations (id),
    amount           NUMERIC(18, 4) NOT NULL DEFAULT 0,
    instock_unknown  BOOLEAN        NOT NULL DEFAULT FALSE,
    lot_code         VARCHAR(100),
    needs_refill     BOOLEAN        NOT NULL DEFAULT FALSE,
    origin           VARCHAR(50),
    condition        VARCHAR(50),
    expiration_date  DATE,
    received_date    DATE,
    created_at       TIMESTAMP      NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP      NOT NULL DEFAULT NOW(),
    created_by       UUID REFERENCES users (id),
    updated_by       UUID REFERENCES users (id),
    is_deleted       BOOLEAN        NOT NULL DEFAULT FALSE,
    deleted_at       TIMESTAMP
);

-- 2. Bảng nhật ký mượn trả part_checkouts
CREATE TABLE IF NOT EXISTS part_checkouts (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    part_id           UUID NOT NULL REFERENCES parts (id),
    part_lot_id       UUID REFERENCES part_lots (id),
    store_location_id UUID REFERENCES store_locations (id),
    taken_by          UUID NOT NULL REFERENCES users (id),
    quantity          NUMERIC(18, 4) NOT NULL DEFAULT 1,
    returned_quantity NUMERIC(18, 4) NOT NULL DEFAULT 0,
    taken_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    returned_at       TIMESTAMP,
    purpose           TEXT,
    repair_order_id   UUID REFERENCES repair_orders (id),
    condition_status  VARCHAR(30),
    checkout_status   VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    notes             TEXT,
    created_at        TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by        UUID REFERENCES users (id),
    updated_by        UUID REFERENCES users (id),
    is_deleted        BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at        TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_part_checkouts_part_id ON part_checkouts (part_id);
CREATE INDEX IF NOT EXISTS idx_part_checkouts_location_id ON part_checkouts (store_location_id);
CREATE INDEX IF NOT EXISTS idx_part_checkouts_taken_by ON part_checkouts (taken_by);
CREATE INDEX IF NOT EXISTS idx_part_checkouts_status ON part_checkouts (checkout_status);
CREATE INDEX IF NOT EXISTS idx_part_checkouts_taken_at ON part_checkouts (taken_at DESC);

-- Đảm bảo chỉ mục qr_code trên bảng store_locations
ALTER TABLE store_locations ADD COLUMN IF NOT EXISTS qr_code TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS uc_store_locations_qr_code
    ON store_locations (qr_code)
    WHERE qr_code IS NOT NULL;
