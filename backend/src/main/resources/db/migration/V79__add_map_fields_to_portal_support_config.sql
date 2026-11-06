-- V79: Bổ sung các trường cấu hình bản đồ động cho portal_support_configs
ALTER TABLE portal_support_configs
ADD COLUMN IF NOT EXISTS map_url VARCHAR(1000) DEFAULT 'https://www.google.com/maps/search/?api=1&query=243+Quốc+Lộ+1A,+Tam+Bình,+TP+Hồ+Chí+Minh',
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION DEFAULT 10.854611,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION DEFAULT 106.703212,
ADD COLUMN IF NOT EXISTS map_image_url VARCHAR(1000);

UPDATE portal_support_configs
SET map_url = 'https://www.google.com/maps/search/?api=1&query=243+Quốc+Lộ+1A,+Tam+Bình,+TP+Hồ+Chí+Minh',
    latitude = 10.854611,
    longitude = 106.703212
WHERE id = '00000000-0000-0000-0000-000000000001'
  AND (map_url IS NULL OR latitude IS NULL);

