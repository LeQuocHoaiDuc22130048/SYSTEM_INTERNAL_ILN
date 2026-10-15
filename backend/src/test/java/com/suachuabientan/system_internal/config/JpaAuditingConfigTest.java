package com.suachuabientan.system_internal.config;

import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.enums.UserStatus;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;

class JpaAuditingConfigTest {
    @AfterEach void cleanup() { SecurityContextHolder.clearContext(); }

    @Test void auditUsesTheJwtPrincipalUserId() {
        UserEntity user = UserEntity.builder().role(UserRole.EMPLOYEE).status(UserStatus.ACTIVE).build();
        user.setId(UUID.randomUUID());
        CustomUserDetails principal = new CustomUserDetails(user);
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(principal, null, principal.getAuthorities()));
        assertEquals(user.getId(), new JpaAuditingConfig().auditorProvider().getCurrentAuditor().orElse(null));
    }

    @Test void anonymousDoesNotFabricateAnAuditIdentity() {
        assertTrue(new JpaAuditingConfig().auditorProvider().getCurrentAuditor().isEmpty());
    }
}
