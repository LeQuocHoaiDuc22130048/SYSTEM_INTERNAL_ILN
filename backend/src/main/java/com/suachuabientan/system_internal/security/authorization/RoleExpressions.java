package com.suachuabientan.system_internal.security.authorization;

public final class RoleExpressions {
    public static final String AUTHENTICATED = "isAuthenticated()";
    public static final String ANY_ACTIVE_USER =
            "hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'TECHNICIAN', 'WAREHOUSE', 'EMPLOYEE')";
    public static final String MANAGER_OR_ABOVE =
            "hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')";
    public static final String ADMIN_OR_ABOVE =
            "hasAnyRole('SUPER_ADMIN', 'ADMIN')";
    public static final String SUPER_ADMIN = "hasRole('SUPER_ADMIN')";
    public static final String WAREHOUSE_VIEW =
            "hasAuthority('WAREHOUSE_VIEW') or hasRole('SUPER_ADMIN')";
    public static final String WAREHOUSE_MANAGE =
            "hasAuthority('WAREHOUSE_MANAGE') or hasRole('SUPER_ADMIN')";
    public static final String WAREHOUSE_DELETE =
            "hasAuthority('WAREHOUSE_DELETE') or hasRole('SUPER_ADMIN')";

    private RoleExpressions() {
    }
}
