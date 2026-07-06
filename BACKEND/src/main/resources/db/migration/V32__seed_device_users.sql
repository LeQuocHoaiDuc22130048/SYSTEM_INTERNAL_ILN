-- Drop the devices table since we will query users and active sessions instead
DROP TABLE IF EXISTS devices;

-- Insert default user accounts representing device terminals
-- Password hash for 'device123' (BCrypt strength 12)
-- '$2a$12$Rpx7gTteCym9U8.OpxZ09.9Vw/H9r2NspxK3jFjK.U6n/O.9yR2mO'

INSERT INTO users (id, username, password_hash, full_name, employee_code, department, role, status, is_deleted) VALUES
('b3a62884-6014-41bb-9852-6d2745d12001', 'att_device_main', '$2a$12$Rpx7gTteCym9U8.OpxZ09.9Vw/H9r2NspxK3jFjK.U6n/O.9yR2mO', 'Máy Chấm Công Cửa Chính', 'ATT-FREAD-01', 'Chấm Công', 'ATTENDANCE'::user_role, 'ACTIVE'::user_status, FALSE),
('b3a62884-6014-41bb-9852-6d2745d12002', 'att_device_back', '$2a$12$Rpx7gTteCym9U8.OpxZ09.9Vw/H9r2NspxK3jFjK.U6n/O.9yR2mO', 'Máy Chấm Công Cửa Sau', 'ATT-FREAD-02', 'Chấm Công', 'ATTENDANCE'::user_role, 'ACTIVE'::user_status, FALSE),
('b3a62884-6014-41bb-9852-6d2745d12003', 'att_camera_hall', '$2a$12$Rpx7gTteCym9U8.OpxZ09.9Vw/H9r2NspxK3jFjK.U6n/O.9yR2mO', 'Camera AI Sảnh Chính', 'ATT-CAM-03', 'Chấm Công', 'ATTENDANCE'::user_role, 'ACTIVE'::user_status, FALSE),
('b3a62884-6014-41bb-9852-6d2745d12004', 'wh_scanner_in', '$2a$12$Rpx7gTteCym9U8.OpxZ09.9Vw/H9r2NspxK3jFjK.U6n/O.9yR2mO', 'Barcode Scanner Nhập Kho', 'WH-SCAN-01', 'Kho Vận', 'WAREHOUSE'::user_role, 'ACTIVE'::user_status, FALSE),
('b3a62884-6014-41bb-9852-6d2745d12005', 'wh_scanner_out', '$2a$12$Rpx7gTteCym9U8.OpxZ09.9Vw/H9r2NspxK3jFjK.U6n/O.9yR2mO', 'Barcode Scanner Xuất Kho', 'WH-SCAN-02', 'Kho Vận', 'WAREHOUSE'::user_role, 'ACTIVE'::user_status, FALSE),
('b3a62884-6014-41bb-9852-6d2745d12006', 'wh_tablet_mgr', '$2a$12$Rpx7gTteCym9U8.OpxZ09.9Vw/H9r2NspxK3jFjK.U6n/O.9yR2mO', 'Tablet Quản Lý Kho Bãi', 'WH-TAB-01', 'Kho Vận', 'WAREHOUSE'::user_role, 'ACTIVE'::user_status, FALSE),
('b3a62884-6014-41bb-9852-6d2745d12007', 'tech_pad_a', '$2a$12$Rpx7gTteCym9U8.OpxZ09.9Vw/H9r2NspxK3jFjK.U6n/O.9yR2mO', 'Máy tính bảng Kỹ thuật A', 'TECH-PAD-01', 'Kỹ Thuật', 'TECHNICIAN'::user_role, 'ACTIVE'::user_status, FALSE),
('b3a62884-6014-41bb-9852-6d2745d12008', 'tech_pad_b', '$2a$12$Rpx7gTteCym9U8.OpxZ09.9Vw/H9r2NspxK3jFjK.U6n/O.9yR2mO', 'Máy tính bảng Kỹ thuật B', 'TECH-PAD-02', 'Kỹ Thuật', 'TECHNICIAN'::user_role, 'ACTIVE'::user_status, FALSE),
('b3a62884-6014-41bb-9852-6d2745d12009', 'tech_app_user1', '$2a$12$Rpx7gTteCym9U8.OpxZ09.9Vw/H9r2NspxK3jFjK.U6n/O.9yR2mO', 'Mobile App Kỹ thuật viên 1', 'TECH-MOB-01', 'Kỹ Thuật', 'TECHNICIAN'::user_role, 'ACTIVE'::user_status, FALSE)
ON CONFLICT (username) DO NOTHING;

-- Assign roles in user_roles table
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM users u CROSS JOIN roles r 
WHERE u.username = 'att_device_main' AND r.code = 'ATTENDANCE'
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM users u CROSS JOIN roles r 
WHERE u.username = 'att_device_back' AND r.code = 'ATTENDANCE'
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM users u CROSS JOIN roles r 
WHERE u.username = 'att_camera_hall' AND r.code = 'ATTENDANCE'
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM users u CROSS JOIN roles r 
WHERE u.username = 'wh_scanner_in' AND r.code = 'WAREHOUSE'
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM users u CROSS JOIN roles r 
WHERE u.username = 'wh_scanner_out' AND r.code = 'WAREHOUSE'
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM users u CROSS JOIN roles r 
WHERE u.username = 'wh_tablet_mgr' AND r.code = 'WAREHOUSE'
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM users u CROSS JOIN roles r 
WHERE u.username = 'tech_pad_a' AND r.code = 'TECHNICIAN'
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM users u CROSS JOIN roles r 
WHERE u.username = 'tech_pad_b' AND r.code = 'TECHNICIAN'
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM users u CROSS JOIN roles r 
WHERE u.username = 'tech_app_user1' AND r.code = 'TECHNICIAN'
ON CONFLICT DO NOTHING;

-- Seed initial active sessions for some of these devices to make them ONLINE
INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at, is_revoked, device_info, created_at) VALUES
(gen_random_uuid(), 'b3a62884-6014-41bb-9852-6d2745d12001', 'simulated_hash_1', NOW() + INTERVAL '24 hours', FALSE, 'Simulated Device IP: 192.168.10.50', NOW()),
(gen_random_uuid(), 'b3a62884-6014-41bb-9852-6d2745d12002', 'simulated_hash_2', NOW() + INTERVAL '24 hours', FALSE, 'Simulated Device IP: 192.168.10.51', NOW()),
(gen_random_uuid(), 'b3a62884-6014-41bb-9852-6d2745d12004', 'simulated_hash_4', NOW() + INTERVAL '24 hours', FALSE, 'Simulated Device IP: 192.168.20.10', NOW()),
(gen_random_uuid(), 'b3a62884-6014-41bb-9852-6d2745d12005', 'simulated_hash_5', NOW() + INTERVAL '24 hours', FALSE, 'Simulated Device IP: 192.168.20.11', NOW()),
(gen_random_uuid(), 'b3a62884-6014-41bb-9852-6d2745d12007', 'simulated_hash_7', NOW() + INTERVAL '24 hours', FALSE, 'Simulated Device IP: 10.0.1.101', NOW()),
(gen_random_uuid(), 'b3a62884-6014-41bb-9852-6d2745d12009', 'simulated_hash_9', NOW() + INTERVAL '24 hours', FALSE, 'Simulated Device IP: 10.0.2.15', NOW())
ON CONFLICT (token_hash) DO NOTHING;
