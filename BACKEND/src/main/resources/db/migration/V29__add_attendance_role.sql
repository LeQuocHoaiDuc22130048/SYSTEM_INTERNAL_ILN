-- Add ATTENDANCE to user_role enum
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'ATTENDANCE';

-- Register ATTENDANCE role in roles table
INSERT INTO roles (code, name, description, system_role)
VALUES ('ATTENDANCE', 'Attendance', 'Attendance machine access', TRUE)
ON CONFLICT (code) DO NOTHING;

-- Grant ATTENDANCE_VIEW permission to ATTENDANCE role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code = 'ATTENDANCE_VIEW'
WHERE r.code = 'ATTENDANCE'
ON CONFLICT DO NOTHING;
