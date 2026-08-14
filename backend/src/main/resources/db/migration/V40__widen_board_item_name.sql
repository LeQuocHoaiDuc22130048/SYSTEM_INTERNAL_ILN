-- Widen board_items.name from VARCHAR(200) to TEXT to remove the 200 character limit
ALTER TABLE board_items
    ALTER COLUMN name TYPE TEXT;

-- Widen category and location columns to VARCHAR(255) to match new DTO limits
ALTER TABLE board_items
    ALTER COLUMN category TYPE VARCHAR(255),
    ALTER COLUMN location TYPE VARCHAR(255);
