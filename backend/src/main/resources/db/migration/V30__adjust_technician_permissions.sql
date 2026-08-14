-- Remove all existing permissions for TECHNICIAN role
DELETE FROM role_permissions
WHERE role_id = (SELECT id FROM roles WHERE code = 'TECHNICIAN');

-- Grant only repair and profile permissions to TECHNICIAN role (including REPAIR_ASSIGN for full order permissions)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.code = 'TECHNICIAN'
  AND p.code IN (
    'REPAIR_VIEW',
    'REPAIR_MANAGE',
    'REPAIR_ASSIGN',
    'PROFILE_VIEW',
    'PROFILE_UPDATE_SELF'
  )
ON CONFLICT DO NOTHING;
