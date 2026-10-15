INSERT INTO permissions (code, module, name, description) VALUES
('DEVICE_VIEW', 'DEVICE', 'Xem thiết bị', 'Xem trạng thái thiết bị'),
('DEVICE_MANAGE', 'DEVICE', 'Quản lý thiết bị', 'Thêm, sửa và quản lý thiết bị'),
('BANNER_MANAGE', 'BANNER', 'Quản lý banner', 'Quản lý banner ứng dụng'),
('APP_UPDATE_MANAGE', 'UPDATE', 'Phát hành ứng dụng', 'Quản lý các bản phát hành ứng dụng'),
('PERMISSION_MANAGE', 'AUTH', 'Quản trị phân quyền', 'Quản lý quyền riêng của tài khoản'),
('REPAIR_DELETE', 'REPAIR', 'Xóa đơn sửa chữa', 'Xóa đơn sửa chữa trong phạm vi được phép')
ON CONFLICT (code) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.code IN ('SUPER_ADMIN', 'ADMIN')
AND p.code IN ('DEVICE_VIEW', 'DEVICE_MANAGE', 'BANNER_MANAGE', 'APP_UPDATE_MANAGE', 'PERMISSION_MANAGE', 'REPAIR_DELETE')
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.code = 'MANAGER' AND p.code IN ('DEVICE_VIEW', 'DEVICE_MANAGE', 'BANNER_MANAGE', 'REPAIR_DELETE')
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.code IN ('TECHNICIAN', 'WAREHOUSE', 'EMPLOYEE') AND p.code = 'DEVICE_VIEW'
ON CONFLICT DO NOTHING;

-- Preserve explicit user overrides: this migration changes role defaults only.
