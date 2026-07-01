package com.suachuabientan.system_internal.modules.auth.service;

import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class RbacService {
    private final JdbcTemplate jdbcTemplate;

    @Transactional(readOnly = true)
    public List<String> getRoleCodes(UUID userId) {
        return jdbcTemplate.queryForList("""
                SELECT DISTINCT r.code
                FROM user_roles ur
                JOIN roles r ON r.id = ur.role_id
                WHERE ur.user_id = ?
                ORDER BY r.code
                """, String.class, userId);
    }

    @Transactional(readOnly = true)
    public List<String> getPermissionCodes(UUID userId) {
        return jdbcTemplate.queryForList("""
                SELECT DISTINCT p.code
                FROM user_roles ur
                JOIN role_permissions rp ON rp.role_id = ur.role_id
                JOIN permissions p ON p.id = rp.permission_id
                WHERE ur.user_id = ?
                ORDER BY p.code
                """, String.class, userId);
    }

    @Transactional
    public void ensurePrimaryRoleAssigned(UUID userId, UserRole role) {
        ensureRoleAssigned(userId, role.name());
    }

    @Transactional
    public void ensureRoleAssigned(UUID userId, String roleCode) {
        jdbcTemplate.update("""
                INSERT INTO user_roles (user_id, role_id)
                SELECT ?, r.id
                FROM roles r
                WHERE r.code = ?
                ON CONFLICT DO NOTHING
                """, userId, roleCode);
    }

    @Transactional
    public void updateRole(UUID userId, UserRole role) {
        jdbcTemplate.update("DELETE FROM user_roles WHERE user_id = ?", userId);
        ensurePrimaryRoleAssigned(userId, role);
    }
}
