package com.suachuabientan.system_internal.config;

import com.suachuabientan.system_internal.common.enums.UserRole;
import com.suachuabientan.system_internal.common.enums.UserStatus;
import com.suachuabientan.system_internal.modules.auth.domain.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

@Slf4j
@Component
@RequiredArgsConstructor
public class DataInitializer implements ApplicationRunner {
    private final UserRepository  userRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${app.init.super-admin.username}")
    private String superAdminUsername;

    @Value("${app.init.super-admin.password}")
    private String superAdminPassword;

    @Value("${app.init.super-admin.full-name}")
    private String superAdminFullName;

    // ── ADMIN (tuỳ chọn) ───────────────────────────────────────────

    @Value("${app.init.admin.username}")
    private String adminUsername;

    @Value("${app.init.admin.password}")
    private String adminPassword;

    @Value("${app.init.admin.full-name}")
    private String adminFullName;


    @Override
    public void run(ApplicationArguments args) throws Exception {
        log.info("=== DataInitializer: Kiểm tra tài khoản mặc định ===");

        initSuperAdmin();
        initAdmin();

        log.info("=== DataInitializer: Hoàn tất ===");
    }

    private void initAdmin() {
        if (!StringUtils.hasText(adminUsername)) {
            log.debug("Không có cấu hình ADMIN mặc định — bỏ qua.");
            return;
        }

        if (userRepository.existsByUsernameAndIsDeletedFalse(adminUsername)) {
            log.info("✓ ADMIN '{}' đã tồn tại — bỏ qua.", adminUsername);
            return;
        }

        if (!StringUtils.hasText(adminPassword)) {
            log.warn("⚠ ADMIN username được cấu hình nhưng thiếu password — bỏ qua tạo ADMIN.");
            return;
        }

        warnIfDefaultPassword(adminPassword, "ADMIN", "ADMIN_PASSWORD");

        UserEntity admin = UserEntity.builder()
                .username(adminUsername)
                .passwordHash(passwordEncoder.encode(adminPassword))
                .fullName(adminFullName)
                .role(UserRole.ADMIN)
                .status(UserStatus.ACTIVE)
                .faceEnrolled(false)
                .build();

        userRepository.save(admin);
        log.info("✓ Đã tạo tài khoản ADMIN: username='{}'",
                adminUsername);
    }

    private void initSuperAdmin() {
        if (userRepository.existsByUsernameAndIsDeletedFalse(superAdminUsername)) {
            log.info("✓ SUPER_ADMIN '{}' đã tồn tại — bỏ qua.", superAdminUsername);
            return;
        }

        // Cảnh báo nếu đang dùng mật khẩu mặc định
        warnIfDefaultPassword(superAdminPassword, "SUPER_ADMIN", "SUPER_ADMIN_PASSWORD");

        UserEntity superAdmin = UserEntity.builder()
                .username(superAdminUsername)
                .passwordHash(passwordEncoder.encode(superAdminPassword))
                .fullName(superAdminFullName)
                .role(UserRole.SUPER_ADMIN)
                .status(UserStatus.ACTIVE)
                .faceEnrolled(false)
                .build();

        userRepository.save(superAdmin);
        log.info("✓ Đã tạo tài khoản SUPER_ADMIN: username='{}'",
                superAdminUsername);
    }


    private void warnIfDefaultPassword(String password, String role, String envVarName) {
        if ("Admin@123456".equals(password) || "admin123".equals(password)) {
            log.warn("⚠⚠⚠ CẢNH BÁO BẢO MẬT: {} đang dùng mật khẩu mặc định!", role);
            log.warn("⚠⚠⚠ Hãy set biến môi trường '{}' trước khi deploy production!", envVarName);
        }
    }
}
