-- V61: Add image_position to app_banners table
ALTER TABLE app_banners
    ADD COLUMN IF NOT EXISTS image_position VARCHAR(50) NOT NULL DEFAULT 'RIGHT';

-- Update existing banners to default image_position 'RIGHT'
UPDATE app_banners
SET image_position = 'RIGHT'
WHERE image_position IS NULL;
