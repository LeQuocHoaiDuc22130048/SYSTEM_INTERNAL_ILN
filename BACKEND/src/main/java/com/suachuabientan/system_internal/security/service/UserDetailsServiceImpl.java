package com.suachuabientan.system_internal.security.service;

import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.auth.service.RbacService;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class UserDetailsServiceImpl implements UserDetailsService {
    private final UserRepository userRepository;
    private final RbacService rbacService;

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        UserEntity user = userRepository.findByUsernameAndIsDeletedFalse(username)
                .orElseThrow(() -> new UsernameNotFoundException("Không tìm thấy người dùng: " + username));

        return new CustomUserDetails(
                user,
                rbacService.getRoleCodes(user.getId()),
                rbacService.getPermissionCodes(user.getId()));
    }
}
