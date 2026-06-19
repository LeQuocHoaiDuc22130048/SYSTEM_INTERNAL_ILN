-- Reassign users' primary role in users table
UPDATE users SET role = 'EMPLOYEE' WHERE role = 'RECEPTIONIST';

-- Reassign/Add user_roles association for those users to 'EMPLOYEE' role
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u
CROSS JOIN roles r
WHERE u.role = 'EMPLOYEE' AND r.code = 'EMPLOYEE'
ON CONFLICT DO NOTHING;

-- Delete the RECEPTIONIST role from roles table (this cascades to role_permissions and user_roles)
DELETE FROM roles WHERE code = 'RECEPTIONIST';
