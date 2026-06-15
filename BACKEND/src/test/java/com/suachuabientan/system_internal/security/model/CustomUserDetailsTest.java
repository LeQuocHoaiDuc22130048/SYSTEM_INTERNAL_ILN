package com.suachuabientan.system_internal.security.model;

import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.enums.UserStatus;
import org.junit.jupiter.api.Test;

import java.util.UUID;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CustomUserDetailsTest {
    @Test
    void exposesSpringRoleAuthority() {
        CustomUserDetails userDetails = userDetails(UserRole.ADMIN);

        assertTrue(userDetails.getAuthorities().stream()
                .anyMatch(authority -> "ROLE_ADMIN".equals(authority.getAuthority())));
    }

    @Test
    void managerOrAboveIncludesManagerAdminAndSuperAdminOnly() {
        assertTrue(userDetails(UserRole.MANAGER).isManagerOrAbove());
        assertTrue(userDetails(UserRole.ADMIN).isManagerOrAbove());
        assertTrue(userDetails(UserRole.SUPER_ADMIN).isManagerOrAbove());
        assertFalse(userDetails(UserRole.EMPLOYEE).isManagerOrAbove());
    }

    @Test
    void includesTableBasedRolesAndPermissionsAsAuthorities() {
        CustomUserDetails userDetails = new CustomUserDetails(
                baseUser(UserRole.EMPLOYEE),
                List.of("TECHNICIAN"),
                List.of("REPAIR_ASSIGN"));

        assertTrue(userDetails.hasRole("TECHNICIAN"));
        assertTrue(userDetails.hasPermission("REPAIR_ASSIGN"));
        assertTrue(userDetails.getAuthorities().stream()
                .anyMatch(authority -> "REPAIR_ASSIGN".equals(authority.getAuthority())));
    }

    private CustomUserDetails userDetails(UserRole role) {
        return new CustomUserDetails(baseUser(role));
    }

    private UserEntity baseUser(UserRole role) {
        UserEntity user = new UserEntity();
        user.setId(UUID.randomUUID());
        user.setUsername(role.name().toLowerCase());
        user.setPasswordHash("hash");
        user.setRole(role);
        user.setStatus(UserStatus.ACTIVE);
        return user;
    }
}
