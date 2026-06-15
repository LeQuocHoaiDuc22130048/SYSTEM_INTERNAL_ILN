ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'TECHNICIAN';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'WAREHOUSE';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'RECEPTIONIST';

CREATE TABLE IF NOT EXISTS roles
(
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code        VARCHAR(50)  NOT NULL UNIQUE,
    name        VARCHAR(100) NOT NULL,
    description TEXT,
    system_role BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS permissions
(
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code        VARCHAR(80)  NOT NULL UNIQUE,
    module      VARCHAR(50)  NOT NULL,
    name        VARCHAR(100) NOT NULL,
    description TEXT,
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_roles
(
    user_id    UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    role_id    UUID NOT NULL REFERENCES roles (id) ON DELETE CASCADE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, role_id)
);

CREATE TABLE IF NOT EXISTS role_permissions
(
    role_id       UUID NOT NULL REFERENCES roles (id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions (id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE INDEX IF NOT EXISTS idx_user_roles_role_id ON user_roles (role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_permission_id ON role_permissions (permission_id);
CREATE INDEX IF NOT EXISTS idx_permissions_module ON permissions (module);

INSERT INTO roles (code, name, description, system_role)
VALUES
    ('SUPER_ADMIN', 'Super Admin', 'Full system access', TRUE),
    ('ADMIN', 'Admin', 'Administrative access', TRUE),
    ('MANAGER', 'Manager', 'Team and operation management', TRUE),
    ('TECHNICIAN', 'Technician', 'Repair technician access', TRUE),
    ('WAREHOUSE', 'Warehouse', 'Inventory and warehouse access', TRUE),
    ('RECEPTIONIST', 'Receptionist', 'Front desk and intake access', TRUE),
    ('EMPLOYEE', 'Employee', 'Default employee access', TRUE)
ON CONFLICT (code) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    system_role = EXCLUDED.system_role,
    updated_at = NOW();

INSERT INTO permissions (code, module, name, description)
VALUES
    ('DASHBOARD_VIEW', 'DASHBOARD', 'View dashboard', 'View operational dashboard'),
    ('REPAIR_VIEW', 'REPAIR', 'View repair orders', 'View repair order list and detail'),
    ('REPAIR_MANAGE', 'REPAIR', 'Manage repair orders', 'Create and update repair orders'),
    ('REPAIR_ASSIGN', 'REPAIR', 'Assign repair orders', 'Assign technicians and reorder work'),
    ('WAREHOUSE_VIEW', 'INVENTORY', 'View warehouse', 'View warehouse board inventory'),
    ('WAREHOUSE_MANAGE', 'INVENTORY', 'Manage warehouse', 'Create and update warehouse board inventory'),
    ('WAREHOUSE_DELETE', 'INVENTORY', 'Delete warehouse items', 'Soft delete warehouse board inventory'),
    ('MESSAGING_USE', 'MESSAGING', 'Use messaging', 'Use internal conversations and messages'),
    ('NOTIFICATION_VIEW', 'NOTIFICATION', 'View notifications', 'View and update own notifications'),
    ('ATTENDANCE_VIEW', 'ATTENDANCE', 'View attendance', 'View own attendance'),
    ('ATTENDANCE_MANAGE', 'ATTENDANCE', 'Manage attendance', 'Manage attendance reports, schedules, and manual check-in'),
    ('EMPLOYEE_MANAGE', 'EMPLOYEE', 'Manage employees', 'View and update employee records'),
    ('ACCOUNT_APPROVE', 'AUTH', 'Approve accounts', 'Approve or reject account requests'),
    ('EMPLOYEE_SECURITY_MANAGE', 'EMPLOYEE', 'Manage employee security', 'Suspend accounts and manage face enrollment'),
    ('PROFILE_VIEW', 'PROFILE', 'View profile', 'View own profile'),
    ('PROFILE_UPDATE_SELF', 'PROFILE', 'Update own profile', 'Update own profile information')
ON CONFLICT (code) DO UPDATE
SET module = EXCLUDED.module,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    updated_at = NOW();

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.code = 'SUPER_ADMIN'
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
    'DASHBOARD_VIEW',
    'REPAIR_VIEW',
    'REPAIR_MANAGE',
    'REPAIR_ASSIGN',
    'WAREHOUSE_VIEW',
    'WAREHOUSE_MANAGE',
    'WAREHOUSE_DELETE',
    'MESSAGING_USE',
    'NOTIFICATION_VIEW',
    'ATTENDANCE_VIEW',
    'ATTENDANCE_MANAGE',
    'EMPLOYEE_MANAGE',
    'ACCOUNT_APPROVE',
    'EMPLOYEE_SECURITY_MANAGE',
    'PROFILE_VIEW',
    'PROFILE_UPDATE_SELF'
)
WHERE r.code = 'ADMIN'
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
    'DASHBOARD_VIEW',
    'REPAIR_VIEW',
    'REPAIR_MANAGE',
    'REPAIR_ASSIGN',
    'WAREHOUSE_VIEW',
    'WAREHOUSE_MANAGE',
    'MESSAGING_USE',
    'NOTIFICATION_VIEW',
    'ATTENDANCE_VIEW',
    'ATTENDANCE_MANAGE',
    'EMPLOYEE_MANAGE',
    'ACCOUNT_APPROVE',
    'PROFILE_VIEW',
    'PROFILE_UPDATE_SELF'
)
WHERE r.code = 'MANAGER'
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
    'REPAIR_VIEW',
    'REPAIR_MANAGE',
    'WAREHOUSE_VIEW',
    'WAREHOUSE_MANAGE',
    'MESSAGING_USE',
    'NOTIFICATION_VIEW',
    'ATTENDANCE_VIEW',
    'PROFILE_VIEW',
    'PROFILE_UPDATE_SELF'
)
WHERE r.code IN ('EMPLOYEE', 'TECHNICIAN', 'WAREHOUSE', 'RECEPTIONIST')
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u
JOIN roles r ON r.code = u.role::TEXT
WHERE u.is_deleted = FALSE
ON CONFLICT DO NOTHING;
