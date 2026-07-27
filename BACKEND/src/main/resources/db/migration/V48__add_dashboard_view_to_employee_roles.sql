-- ── V48: Add DASHBOARD_VIEW and WAREHOUSE_VIEW permissions to EMPLOYEE, TECHNICIAN, WAREHOUSE roles ──────────────────

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN ('DASHBOARD_VIEW', 'WAREHOUSE_VIEW')
WHERE r.code IN ('EMPLOYEE', 'TECHNICIAN', 'WAREHOUSE')
ON CONFLICT DO NOTHING;
