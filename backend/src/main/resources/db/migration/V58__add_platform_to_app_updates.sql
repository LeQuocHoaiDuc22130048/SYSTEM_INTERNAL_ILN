-- V58: Add platform to app_updates table and add index for platform filtering

ALTER TABLE app_updates 
ADD COLUMN IF NOT EXISTS platform VARCHAR(20) NOT NULL DEFAULT 'ANDROID';

CREATE INDEX IF NOT EXISTS idx_app_updates_platform_status 
ON app_updates (platform, status, is_deleted);

-- Seed initial iOS release record
INSERT INTO app_updates (id, created_at, updated_at, is_deleted, version, changelog, download_url, mandatory, status, released_at, platform)
VALUES 
(
    'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 
    NOW(), 
    NOW(), 
    false, 
    '1.1.6', 
    '- Cập nhật phiên bản iOS mới nhất v1.1.6' || CHR(10) || '- Tối ưu hóa giao diện và trải nghiệm người dùng trên thiết bị Apple' || CHR(10) || '- Đồng bộ các tính năng điểm danh và giám sát sửa chữa', 
    'https://apps.apple.com/app/id6740000000', 
    false, 
    'RELEASED', 
    NOW(),
    'IOS'
)
ON CONFLICT (id) DO NOTHING;
