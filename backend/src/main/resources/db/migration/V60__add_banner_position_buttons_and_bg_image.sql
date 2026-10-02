-- V60: Add button_position, buttons_json, and background_image_url to app_banners
ALTER TABLE app_banners
    ADD COLUMN IF NOT EXISTS button_position VARCHAR(50) NOT NULL DEFAULT 'BOTTOM_LEFT',
    ADD COLUMN IF NOT EXISTS buttons_json TEXT,
    ADD COLUMN IF NOT EXISTS background_image_url VARCHAR(500);

-- Update existing default banner row with buttons_json
UPDATE app_banners
SET button_position = 'BOTTOM_LEFT',
    buttons_json = '[{"text":"Đặt lịch ngay","actionType":"BOOKING","actionValue":"Gói bảo trì ưu đãi 25%","styleType":"PRIMARY"}]'
WHERE id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' AND (buttons_json IS NULL OR buttons_json = '');
