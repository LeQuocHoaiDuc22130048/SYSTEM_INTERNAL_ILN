package com.suachuabientan.system_internal.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.flyway.FlywayMigrationStrategy;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class FlywayConfig {
    private static final Logger log = LoggerFactory.getLogger(FlywayConfig.class);

    @Bean
    public FlywayMigrationStrategy flywayMigrationStrategy() {
        return flyway -> {
            try {
                log.info("Thực thi Flyway repair để chuẩn hóa lịch sử schema trước khi migrate...");
                flyway.repair();
            } catch (Exception e) {
                log.warn("Cảnh báo Flyway repair: {}", e.getMessage());
            }
            log.info("Thực thi Flyway migration nâng cấp database...");
            flyway.migrate();
            log.info("Flyway migration hoàn tất thành công.");
        };
    }
}
