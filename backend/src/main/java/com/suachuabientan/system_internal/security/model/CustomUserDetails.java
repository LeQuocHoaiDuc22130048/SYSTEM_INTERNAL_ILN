package com.suachuabientan.system_internal.security.model;

import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import lombok.Getter;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

@Getter
public class CustomUserDetails implements UserDetails {

    private final UUID userId;
    private final String username;
    private final String password;
    private final String role;
    private final boolean active;
    private final Set<String> roles;
    private final Set<String> permissions;
    private final List<SimpleGrantedAuthority> authorities;

    public CustomUserDetails(UserEntity user) {
        this(user, Set.of(), Set.of());
    }

    public CustomUserDetails(UserEntity user, Collection<String> roleCodes, Collection<String> permissionCodes) {
        this.userId = user.getId();
        this.username = user.getUsername();
        this.password = user.getPasswordHash();
        this.role = user.getRole().name();
        this.active = user.isActive();
        LinkedHashSet<String> mergedRoles = new LinkedHashSet<>();
        mergedRoles.add(user.getRole().name());
        mergedRoles.addAll(roleCodes);
        this.roles = Set.copyOf(mergedRoles);
        this.permissions = Set.copyOf(permissionCodes);
        this.authorities = mergedRoles.stream()
                .map(roleCode -> new SimpleGrantedAuthority("ROLE_" + roleCode))
                .collect(java.util.stream.Collectors.toCollection(java.util.ArrayList::new));
        this.authorities.addAll(permissionCodes.stream()
                .map(SimpleGrantedAuthority::new)
                .toList());
    }

    @Override
    public Collection<SimpleGrantedAuthority> getAuthorities() {
        return authorities;
    }

    @Override
    public String getPassword() {
        return password;
    }

    @Override
    public String getUsername() {
        return username;
    }

    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    @Override
    public boolean isAccountNonLocked() {
        return active;
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }

    @Override
    public boolean isEnabled() {
        return active;
    }

    public boolean hasRole(String roleName) {
        return this.roles.contains(roleName);
    }

    public boolean isManagerOrAbove() {
        return hasRole("MANAGER") || hasRole("ADMIN") || hasRole("SUPER_ADMIN");
    }

    public boolean hasPermission(String permissionCode) {
        return this.permissions.contains(permissionCode);
    }
}
