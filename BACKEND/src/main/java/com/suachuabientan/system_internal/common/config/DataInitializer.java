package com.suachuabientan.system_internal.common.config;

import com.suachuabientan.system_internal.common.enums.Roles;
import com.suachuabientan.system_internal.modules.auth.domain.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
@RequiredArgsConstructor
public class DataInitializer implements CommandLineRunner {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${app.init.admin.username}")
    private String adminUsername;

    @Value("${app.init.admin.password}")
    private String adminPassword;

    @Value("${app.init.admin.full-name}")
    private String adminFullName;


    @Value("${app.init.boss.username}")
    private String bossUsername;

    @Value("${app.init.boss.password}")
    private String bossPassword;

    @Value("${app.init.boss.full-name}")
    private String bossFullName;

    @Override
    public void run(String... args) throws Exception {
        if (userRepository.count() == 0) {
            UserEntity admin = UserEntity.builder()
                    .username(adminUsername)
                    .password(passwordEncoder.encode(adminPassword))
                    .fullName(adminFullName)
                    .role(Roles.ADMIN.getDisplayName())
                    .isActive(true)
                    .build();

            userRepository.save(admin);
        }

        if (userRepository.findByUsername(bossUsername).isEmpty()) {
            UserEntity boss = UserEntity.builder()
                    .username(bossUsername)
                    .password(passwordEncoder.encode(bossPassword))
                    .fullName(bossFullName)
                    .role(Roles.BOSS.getDisplayName())
                    .isActive(true)
                    .build();

            userRepository.save(boss);
        }
    }
}
