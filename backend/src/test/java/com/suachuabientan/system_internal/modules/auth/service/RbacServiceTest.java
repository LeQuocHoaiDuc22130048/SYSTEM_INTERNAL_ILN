package com.suachuabientan.system_internal.modules.auth.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import java.util.Map;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;

class RbacServiceTest {
    JdbcTemplate jdbc;
    RbacService service;
    UUID userId = UUID.randomUUID();

    @BeforeEach void setup() {
        jdbc = new JdbcTemplate(new DriverManagerDataSource("jdbc:h2:mem:rbac-" + UUID.randomUUID() + ";DB_CLOSE_DELAY=-1", "sa", ""));
        jdbc.execute("CREATE TABLE permissions(id UUID PRIMARY KEY, code VARCHAR(80) UNIQUE, assignable BOOLEAN DEFAULT TRUE)");
        jdbc.execute("CREATE TABLE user_permissions(user_id UUID, permission_id UUID, granted BOOLEAN)");
        jdbc.execute("CREATE TABLE roles(id UUID PRIMARY KEY, code VARCHAR(50))");
        jdbc.execute("CREATE TABLE user_roles(user_id UUID, role_id UUID)");
        jdbc.execute("CREATE TABLE role_permissions(role_id UUID, permission_id UUID)");
        UUID permissionId = UUID.randomUUID();
        jdbc.update("INSERT INTO permissions(id, code) VALUES (?, ?)", permissionId, "REPAIR_VIEW");
        jdbc.update("INSERT INTO user_permissions VALUES (?, ?, ?)", userId, permissionId, false);
        service = new RbacService(jdbc);
    }

    @Test void emptyOverridesResetPersistedDenials() {
        service.setUserPermissionOverrides(userId, Map.of(), UUID.randomUUID());
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM user_permissions WHERE user_id = ?", Integer.class, userId));
    }

    @Test void unknownCodeIsRejectedWithoutChangingExistingOverrides() {
        assertThrows(BusinessException.class, () -> service.setUserPermissionOverrides(userId, Map.of("UNKNOWN_PERMISSION", true), UUID.randomUUID()));
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM user_permissions WHERE user_id = ?", Integer.class, userId));
    }

    @Test void normalRoleDenialOverridesTheRoleGrantAndResetRestoresIt() {
        UUID role = UUID.randomUUID();
        jdbc.update("INSERT INTO roles VALUES (?, 'ADMIN')", role);
        jdbc.update("INSERT INTO user_roles VALUES (?, ?)", userId, role);
        jdbc.update("INSERT INTO role_permissions SELECT ?, id FROM permissions", role);
        assertTrue(service.getPermissionCodes(userId).isEmpty());
        service.setUserPermissionOverrides(userId, Map.of(), UUID.randomUUID());
        assertEquals(java.util.List.of("REPAIR_VIEW"), service.getPermissionCodes(userId));
    }

    @Test void superAdminKeepsCatalogPermissionsEvenWithAnOldDenial() {
        UUID role = UUID.randomUUID();
        jdbc.update("INSERT INTO roles VALUES (?, 'SUPER_ADMIN')", role);
        jdbc.update("INSERT INTO user_roles VALUES (?, ?)", userId, role);
        assertEquals(java.util.List.of("REPAIR_VIEW"), service.getPermissionCodes(userId));
    }

    @Test void retiredGroupCannotBeGrantedOrReturnedEvenToSuperAdmin() {
        UUID retired = UUID.randomUUID();
        jdbc.update("INSERT INTO permissions(id, code, assignable) VALUES (?, 'REPAIR_MANAGE', FALSE)", retired);
        jdbc.update("INSERT INTO user_permissions VALUES (?, ?, TRUE)", userId, retired);
        UUID role = UUID.randomUUID();
        jdbc.update("INSERT INTO roles VALUES (?, 'SUPER_ADMIN')", role);
        jdbc.update("INSERT INTO user_roles VALUES (?, ?)", userId, role);
        assertEquals(java.util.List.of("REPAIR_VIEW"), service.getPermissionCodes(userId));
        assertThrows(BusinessException.class, () -> service.setUserPermissionOverrides(
                userId, Map.of("REPAIR_MANAGE", true), UUID.randomUUID()));
    }
}
