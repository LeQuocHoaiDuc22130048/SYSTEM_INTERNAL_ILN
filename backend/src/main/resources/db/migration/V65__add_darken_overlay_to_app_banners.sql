-- V65: Add darken_overlay to app_banners table to control background dimming
ALTER TABLE app_banners
    ADD COLUMN IF NOT EXISTS darken_overlay BOOLEAN NOT NULL DEFAULT FALSE;
