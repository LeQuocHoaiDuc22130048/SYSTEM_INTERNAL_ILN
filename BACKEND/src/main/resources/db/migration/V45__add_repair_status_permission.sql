-- ── V45: Add REPAIR_STATUS_UPDATE permission ──────────────────────────────
-- Thêm quyền Cập nhật trạng thái đơn vào hệ thống phân quyền (RBAC)

INSERT INTO permissions (code, module, name, description)
VALUES
    ('REPAIR_STATUS_UPDATE', 'REPAIR', 'Cập nhật trạng thái đơn', 'Cập nhật trạng thái quy trình sửa chữa của đơn hàng')
ON CONFLICT (code) DO UPDATE
SET module = EXCLUDED.module,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    updated_at = NOW();

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code = 'REPAIR_STATUS_UPDATE'
WHERE r.code IN ('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'TECHNICIAN', 'EMPLOYEE', 'WAREHOUSE')
ON CONFLICT DO NOTHING;
