package com.suachuabientan.system_internal.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.flyway.FlywayMigrationStrategy;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

@Configuration
@Profile("docker")
public class FlywayConfig {
    private static final Logger log = LoggerFactory.getLogger(FlywayConfig.class);

    @Value("${app.flyway.repair-on-startup:false}")
    private boolean repairOnStartup;

    @Bean
    public FlywayMigrationStrategy flywayMigrationStrategy() {
        return flyway -> {
            if (repairOnStartup) {
                log.warn("Docker profile is enabled: repairing Flyway schema history before migration");
                flyway.repair();
            }
            flyway.migrate();
        };
    }
}

