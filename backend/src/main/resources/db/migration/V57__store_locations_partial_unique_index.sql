-- V57__store_locations_partial_unique_index.sql

ALTER TABLE store_locations DROP CONSTRAINT IF EXISTS store_locations_code_key;

CREATE UNIQUE INDEX IF NOT EXISTS uc_store_locations_code_active ON store_locations (code) WHERE is_deleted = FALSE;

