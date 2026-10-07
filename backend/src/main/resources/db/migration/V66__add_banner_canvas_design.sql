-- Optional canvas layout; existing banners keep their legacy rendering.
ALTER TABLE app_banners ADD COLUMN IF NOT EXISTS design_json TEXT;
