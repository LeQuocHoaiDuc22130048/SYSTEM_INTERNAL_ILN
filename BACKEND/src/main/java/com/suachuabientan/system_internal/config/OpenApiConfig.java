package com.suachuabientan.system_internal.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {
    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI().info(new Info()
                .title("System Internal ILN")
                .version("1.0")
                .description("Tài liệu hướng dẫn sử dụng API cho dự án Spring Boot của tôi.")
                .contact(new Contact()
                        .name("Lê Quốc Hoài Đức")
                        .email("lequochoaiduc04@gmail.com")
                        ).license(new License().name("Apache 2.0").url("https://springdoc.org")));
    }
}
