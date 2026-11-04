-- V76: Enhance app_updates with sha256, file_size, min_supported_version, and channel

ALTER TABLE app_updates
ADD COLUMN IF NOT EXISTS sha256 VARCHAR(64),
ADD COLUMN IF NOT EXISTS file_size BIGINT,
ADD COLUMN IF NOT EXISTS min_supported_version VARCHAR(50),
ADD COLUMN IF NOT EXISTS channel VARCHAR(20) NOT NULL DEFAULT 'PRODUCTION';

CREATE INDEX IF NOT EXISTS idx_app_updates_platform_channel_status
ON app_updates (platform, channel, status, is_deleted);

-- Update placeholder iOS App Store URL to official Unlisted App Store URL
UPDATE app_updates
SET download_url = 'https://apps.apple.com/us/app/inverter-like-new-system/id6809314317'
WHERE platform = 'IOS'
  AND download_url = 'https://apps.apple.com/app/id6740000000';

-- Update default customer portal support phone number to 0964 266 771
UPDATE portal_support_config
SET hotline_number = '0964 266 771',
    hotline_label = 'Liên hệ kỹ thuật'
WHERE hotline_number = '0909000000';



