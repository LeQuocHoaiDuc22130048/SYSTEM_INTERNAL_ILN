-- Migration: Add font_family to app_banners
ALTER TABLE app_banners ADD COLUMN font_family VARCHAR(100) DEFAULT 'Be Vietnam Pro' NOT NULL;
