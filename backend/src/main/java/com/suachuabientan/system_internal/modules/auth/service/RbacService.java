package com.suachuabientan.system_internal.modules.auth.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;

import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
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

    /**
     * Lấy tập quyền cuối cùng của user:
     *   = (quyền từ role) UNION (override GRANT) EXCEPT (override DENY)
     */
    @Transactional(readOnly = true)
    public List<String> getPermissionCodes(UUID userId) {
        return jdbcTemplate.queryForList("""
                SELECT code FROM (
                    -- Quyền từ role
                    SELECT DISTINCT p.code
                    FROM user_roles ur
                    JOIN role_permissions rp ON rp.role_id = ur.role_id
                    JOIN permissions p ON p.id = rp.permission_id
                    WHERE ur.user_id = ? AND p.assignable = TRUE

                    UNION

                    -- Override GRANT thêm quyền
                    SELECT p.code
                    FROM user_permissions up
                    JOIN permissions p ON p.id = up.permission_id
                    WHERE up.user_id = ? AND up.granted = TRUE AND p.assignable = TRUE

                    EXCEPT

                    -- Override DENY thu hồi quyền
                    SELECT p.code
                    FROM user_permissions up
                    JOIN permissions p ON p.id = up.permission_id
                    WHERE up.user_id = ? AND up.granted = FALSE AND p.assignable = TRUE
                ) final_perms
                UNION
                SELECT p.code FROM permissions p
                WHERE p.assignable = TRUE AND EXISTS (
                    SELECT 1 FROM user_roles ur JOIN roles r ON r.id = ur.role_id
                    WHERE ur.user_id = ? AND r.code = 'SUPER_ADMIN'
                )
                ORDER BY code
                """, String.class, userId, userId, userId, userId);
    }

    /**
     * Lấy chi tiết permissions của user: từng quyền có nguồn gốc rõ ràng.
     * Trả về List<Map> với keys: code, name, module, from_role, override_granted (nullable boolean)
     */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> getUserPermissionDetails(UUID userId) {
        return jdbcTemplate.queryForList("""
                SELECT
                    p.code,
                    p.name,
                    p.module,
                    p.description,
                    EXISTS (
                        SELECT 1
                        FROM user_roles ur
                        JOIN role_permissions rp ON rp.role_id = ur.role_id
                        WHERE ur.user_id = ? AND rp.permission_id = p.id
                    ) AS from_role,
                    up.granted AS override_granted
                FROM permissions p
                LEFT JOIN user_permissions up ON up.permission_id = p.id AND up.user_id = ?
                WHERE p.assignable = TRUE
                ORDER BY p.module, p.code
                """, userId, userId);
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

    /**
     * Lưu permission overrides cho user.
     * overrides: Map<permissionCode, granted>
     *   - TRUE  = cấp thêm quyền (GRANT)
     *   - FALSE = thu hồi quyền (DENY)
     *   - null  = xóa override (kế thừa từ role)
     */
    @Transactional
    public void setUserPermissionOverrides(UUID userId, Map<String, Boolean> overrides, UUID grantedBy) {
        if (overrides.isEmpty()) {
            clearUserPermissionOverrides(userId);
            return;
        }
        var knownCodes = new java.util.HashSet<>(jdbcTemplate.queryForList("SELECT code FROM permissions WHERE assignable = TRUE", String.class));
        if (!knownCodes.containsAll(overrides.keySet())) {
            throw new BusinessException("Mã quyền không hợp lệ", 400);
        }
        for (Map.Entry<String, Boolean> entry : overrides.entrySet()) {
            String permCode = entry.getKey();
            Boolean granted = entry.getValue();

            if (granted == null) {
                // Xóa override → trở về kế thừa từ role
                jdbcTemplate.update("""
                        DELETE FROM user_permissions
                        WHERE user_id = ?
                          AND permission_id = (SELECT id FROM permissions WHERE code = ?)
                        """, userId, permCode);
            } else {
                // Upsert override
                jdbcTemplate.update("""
                        INSERT INTO user_permissions (user_id, permission_id, granted, granted_by, granted_at)
                        SELECT ?, p.id, ?, ?, NOW()
                        FROM permissions p
                        WHERE p.code = ?
                        ON CONFLICT (user_id, permission_id)
                            DO UPDATE SET granted = EXCLUDED.granted,
                                          granted_by = EXCLUDED.granted_by,
                                          granted_at = NOW()
                        """, userId, granted, grantedBy, permCode);
            }
        }
    }

    /**
     * Xóa toàn bộ overrides của user (reset về mặc định role).
     */
    @Transactional
    public void clearUserPermissionOverrides(UUID userId) {
        jdbcTemplate.update("DELETE FROM user_permissions WHERE user_id = ?", userId);
    }
}
