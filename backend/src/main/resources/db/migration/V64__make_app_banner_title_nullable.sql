-- V64: Make title nullable and default to empty string for full image banners
ALTER TABLE app_banners ALTER COLUMN title DROP NOT NULL;
ALTER TABLE app_banners ALTER COLUMN title SET DEFAULT '';
