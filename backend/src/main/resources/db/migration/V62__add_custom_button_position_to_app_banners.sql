-- V62: Add button position coordinates to app_banners
ALTER TABLE app_banners
    ADD COLUMN IF NOT EXISTS button_top DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS button_bottom DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS button_left DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS button_right DOUBLE PRECISION;
