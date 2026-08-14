INSERT INTO app_updates (id, created_at, updated_at, is_deleted, version, changelog, download_url, mandatory, status, released_at)
VALUES 
(
    'd5d71c4c-3221-4235-862d-0b61c94411a0', 
    NOW() - INTERVAL '30 day', 
    NOW() - INTERVAL '30 day', 
    false, 
    '1.1.0', 
    '- Khởi tạo ứng dụng di động chấm công và giám sát sửa chữa' || CHR(10) || '- Đăng nhập và xác thực tài khoản nhân viên' || CHR(10) || '- Tích hợp quét khuôn mặt offline để chấm công', 
    '/api/v1/app-updates/download/system_internal_v1.1.0.apk', 
    false, 
    'RELEASED', 
    NOW() - INTERVAL '30 day'
),
(
    'a87262ba-cd94-4d87-bc4e-2895f5439c2e', 
    NOW() - INTERVAL '15 day', 
    NOW() - INTERVAL '15 day', 
    false, 
    '1.1.2', 
    '- Tối ưu hóa hiệu năng nhận diện khuôn mặt' || CHR(10) || '- Sửa lỗi đồng bộ dữ liệu chấm công khi mất mạng' || CHR(10) || '- Cập nhật giao diện trang chủ app di động', 
    '/api/v1/app-updates/download/system_internal_v1.1.2.apk', 
    false, 
    'RELEASED', 
    NOW() - INTERVAL '15 day'
),
(
    'f45612ba-e3f4-4ea2-bc78-6548a329ce2f', 
    NOW() - INTERVAL '5 day', 
    NOW() - INTERVAL '5 day', 
    false, 
    '1.1.3', 
    '- Sửa lỗi xóa ghi chú chi tiết đơn hàng' || CHR(10) || '- Cập nhật giao diện mới và sửa lỗi kết nối mạng', 
    '/api/v1/app-updates/download/system_internal_v1.1.3.apk', 
    false, 
    'RELEASED', 
    NOW() - INTERVAL '5 day'
);
