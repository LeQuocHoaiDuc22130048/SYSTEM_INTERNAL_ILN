CREATE TABLE IF NOT EXISTS categories
(
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

CREATE TABLE IF NOT EXISTS store_locations
(
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id        UUID REFERENCES store_locations (id),
    code             VARCHAR(80)  NOT NULL UNIQUE,
    name             VARCHAR(200) NOT NULL,
    description      TEXT,
    is_full          BOOLEAN      NOT NULL DEFAULT FALSE,
    only_single_part BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP    NOT NULL DEFAULT NOW(),
    created_by       UUID REFERENCES users (id),
    updated_by       UUID REFERENCES users (id),
    is_deleted       BOOLEAN      NOT NULL DEFAULT FALSE,
    deleted_at       TIMESTAMP
);

CREATE TABLE IF NOT EXISTS manufacturers
(
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id   UUID REFERENCES manufacturers (id),
    name        VARCHAR(200) NOT NULL,
    description TEXT,
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP    NOT NULL DEFAULT NOW(),
    created_by  UUID REFERENCES users (id),
    updated_by  UUID REFERENCES users (id),
    is_deleted  BOOLEAN      NOT NULL DEFAULT FALSE,
    deleted_at  TIMESTAMP
);

CREATE TABLE IF NOT EXISTS footprints
(
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id   UUID REFERENCES footprints (id),
    name        VARCHAR(200) NOT NULL,
    description TEXT,
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP    NOT NULL DEFAULT NOW(),
    created_by  UUID REFERENCES users (id),
    updated_by  UUID REFERENCES users (id),
    is_deleted  BOOLEAN      NOT NULL DEFAULT FALSE,
    deleted_at  TIMESTAMP
);

CREATE TABLE IF NOT EXISTS measurement_units
(
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id     UUID REFERENCES measurement_units (id),
    name          VARCHAR(100) NOT NULL,
    symbol        VARCHAR(30)  NOT NULL,
    use_si_prefix BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    created_by    UUID REFERENCES users (id),
    updated_by    UUID REFERENCES users (id),
    is_deleted    BOOLEAN      NOT NULL DEFAULT FALSE,
    deleted_at    TIMESTAMP
);

INSERT INTO categories (name, description)
VALUES ('Uncategorized', 'Default category for imported or board-linked parts')
ON CONFLICT DO NOTHING;

INSERT INTO store_locations (code, name, description)
VALUES ('DEFAULT', 'Default warehouse location', 'Fallback normalized warehouse location')
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS parts
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ipn                 VARCHAR(100) NOT NULL UNIQUE,
    name                VARCHAR(200) NOT NULL,
    description         TEXT,
    min_amount          NUMERIC(18, 4) NOT NULL DEFAULT 0,
    manufacturing_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    category_id         UUID NOT NULL REFERENCES categories (id),
    footprint_id        UUID REFERENCES footprints (id),
    manufacturer_id     UUID REFERENCES manufacturers (id),
    measurement_unit_id UUID REFERENCES measurement_units (id),
    created_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by          UUID REFERENCES users (id),
    updated_by          UUID REFERENCES users (id),
    is_deleted          BOOLEAN   NOT NULL DEFAULT FALSE,
    deleted_at          TIMESTAMP
);

CREATE TABLE IF NOT EXISTS part_lots
(
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    part_id          UUID NOT NULL REFERENCES parts (id),
    store_location_id UUID REFERENCES store_locations (id),
    amount           NUMERIC(18, 4) NOT NULL DEFAULT 0,
    instock_unknown  BOOLEAN        NOT NULL DEFAULT FALSE,
    lot_code         VARCHAR(100) UNIQUE,
    needs_refill     BOOLEAN        NOT NULL DEFAULT FALSE,
    expiration_date  DATE,
    created_at       TIMESTAMP      NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP      NOT NULL DEFAULT NOW(),
    created_by       UUID REFERENCES users (id),
    updated_by       UUID REFERENCES users (id),
    is_deleted       BOOLEAN        NOT NULL DEFAULT FALSE,
    deleted_at       TIMESTAMP
);

CREATE TABLE IF NOT EXISTS stock_movements
(
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

ALTER TABLE board_items
    ADD COLUMN IF NOT EXISTS serial_number VARCHAR(100),
    ADD COLUMN IF NOT EXISTS part_id UUID REFERENCES parts (id),
    ADD COLUMN IF NOT EXISTS current_location_id UUID REFERENCES store_locations (id);

ALTER TABLE board_checkouts
    ADD COLUMN IF NOT EXISTS checkout_status VARCHAR(20) NOT NULL DEFAULT 'OPEN';

UPDATE board_checkouts
SET checkout_status = 'RETURNED'
WHERE returned_at IS NOT NULL
  AND checkout_status = 'OPEN';

CREATE UNIQUE INDEX IF NOT EXISTS uc_board_items_serial_number
    ON board_items (serial_number)
    WHERE serial_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_board_items_part_id ON board_items (part_id);
CREATE INDEX IF NOT EXISTS idx_board_items_current_location_id ON board_items (current_location_id);
CREATE INDEX IF NOT EXISTS idx_board_checkouts_status ON board_checkouts (checkout_status);
CREATE INDEX IF NOT EXISTS idx_parts_category_id ON parts (category_id);
CREATE INDEX IF NOT EXISTS idx_part_lots_part_id ON part_lots (part_id);
CREATE INDEX IF NOT EXISTS idx_part_lots_location_id ON part_lots (store_location_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_part_id ON stock_movements (part_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_board_item_id ON stock_movements (board_item_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_ref ON stock_movements (ref_type, ref_id);
