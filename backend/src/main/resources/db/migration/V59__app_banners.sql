-- V59: Create app_banners table for mobile home promotional banners management
CREATE TABLE app_banners
(
    id              UUID                        NOT NULL,
    created_at      TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    updated_at      TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    created_by      UUID,
    updated_by      UUID,
    is_deleted      BOOLEAN                     NOT NULL DEFAULT FALSE,
    deleted_at      TIMESTAMP WITHOUT TIME ZONE,
    title           VARCHAR(255)                NOT NULL,
    badge_text      VARCHAR(100),
    subtitle        VARCHAR(500),
    button_text     VARCHAR(100),
    action_type     VARCHAR(50)                 NOT NULL DEFAULT 'BOOKING',
    action_value    VARCHAR(500),
    image_url       VARCHAR(500),
    gradient_colors VARCHAR(200)                NOT NULL DEFAULT '#2563EB,#4F46E5,#1D4ED8',
    display_order   INT                         NOT NULL DEFAULT 0,
    is_active       BOOLEAN                     NOT NULL DEFAULT TRUE,
    start_date      TIMESTAMP WITHOUT TIME ZONE,
    end_date        TIMESTAMP WITHOUT TIME ZONE,
    CONSTRAINT pk_app_banners PRIMARY KEY (id)
);

CREATE INDEX idx_app_banners_active_order ON app_banners (is_active, display_order, is_deleted);

-- Seed initial promotional banner matching current mobile app design
INSERT INTO app_banners (
    id,
    created_at,
    updated_at,
    is_deleted,
    title,
    badge_text,
    subtitle,
    button_text,
    action_type,
    action_value,
    image_url,
    gradient_colors,
    display_order,
    is_active
) VALUES (
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    NOW(),
    NOW(),
    false,
    'Bảo Trì & Sửa Chữa Inverter',
    '⚡ ƯU ĐÃI ĐẶC BIỆT',
    'Giảm ngay 25% GIÁ TRỊ cho lượt đặt dịch vụ đầu tiên!',
    'Đặt lịch ngay',
    'BOOKING',
    'Gói bảo trì ưu đãi 25%',
    NULL,
    '#2563EB,#4F46E5,#1D4ED8',
    1,
    true
)
ON CONFLICT (id) DO NOTHING;
