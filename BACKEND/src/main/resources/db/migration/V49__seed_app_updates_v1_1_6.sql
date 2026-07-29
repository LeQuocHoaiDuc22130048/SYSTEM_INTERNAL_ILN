INSERT INTO app_updates (id, created_at, updated_at, is_deleted, version, changelog, download_url, mandatory, status, released_at)
VALUES 
(
    'e6714ba1-12a4-4f92-98c1-1234567890a4', 
    NOW() - INTERVAL '3 day', 
    NOW() - INTERVAL '3 day', 
    false, 
    '1.1.4', 
    '- Nâng cấp hệ thống điểm danh và giám sát' || CHR(10) || '- Tối ưu hóa bộ nhớ tạm và lưu trữ ứng dụng', 
    '/api/v1/app-updates/download/system_internal_v1.1.4.apk', 
    false, 
    'RELEASED', 
    NOW() - INTERVAL '3 day'
),
(
    'f7825cb2-23b5-4fa3-a9d2-2345678901b5', 
    NOW() - INTERVAL '2 day', 
    NOW() - INTERVAL '2 day', 
    false, 
    '1.1.5', 
    '- Sửa lỗi đồng bộ dữ liệu khi mất kết nối mạng' || CHR(10) || '- Cập nhật tính năng thông báo nâng cấp', 
    '/api/v1/app-updates/download/system_internal_v1.1.5.apk', 
    false, 
    'RELEASED', 
    NOW() - INTERVAL '2 day'
),
(
    'c8936dc3-34c6-4ab4-b0e3-3456789012c6', 
    NOW(), 
    NOW(), 
    false, 
    '1.1.6', 
    '- Cập nhật phiên bản mới nhất v1.1.6' || CHR(10) || '- Sửa lỗi kẹt phiên bản 1.1.4 trên thiết bị di động' || CHR(10) || '- Cải thiện trải nghiệm và hiệu năng hệ thống', 
    '/api/v1/app-updates/download/system_internal_v1.1.6.apk', 
    true, 
    'RELEASED', 
    NOW()
)
ON CONFLICT (id) DO NOTHING;
