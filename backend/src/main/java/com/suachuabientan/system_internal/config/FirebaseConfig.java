package com.suachuabientan.system_internal.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;

import java.io.IOException;
import java.io.InputStream;
@Slf4j
@Configuration
public class FirebaseConfig {
    @Value("${app.firebase.service-account-path:firebase-service-account.json}")
    private String serviceAccountPath;

    @Value("${app.firebase.project-id:}")
    private String projectId;

    @PostConstruct
    public void initializeFirebase() {
        // Bỏ qua nếu FirebaseApp đã được khởi tạo (tránh lỗi khi hot reload)
        if (!FirebaseApp.getApps().isEmpty()) {
            log.info("Firebase Admin SDK đã được khởi tạo trước đó");
            return;
        }

        try {
            InputStream serviceAccount = loadServiceAccount();

            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                    .build();

            FirebaseApp.initializeApp(options);
            log.info("✓ Firebase Admin SDK khởi tạo thành công");

        } catch (IOException e) {
            // Không throw — app vẫn chạy được, chỉ FCM push bị tắt
            log.warn("⚠ Firebase Admin SDK không khởi tạo được: {}", e.getMessage());
            log.warn("⚠ Push notification sẽ bị tắt. Kiểm tra cấu hình FIREBASE_SERVICE_ACCOUNT_PATH");
        }
    }

    /**
     * Load Service Account JSON từ classpath hoặc file system.
     * Thử classpath trước, nếu không có thì thử file system.
     */
    private InputStream loadServiceAccount() throws IOException {
        // Thử classpath (src/main/resources/)
        try {
            Resource classpathResource = new ClassPathResource(serviceAccountPath);
            if (classpathResource.exists()) {
                log.debug("Load Firebase service account từ classpath: {}", serviceAccountPath);
                return classpathResource.getInputStream();
            }
        } catch (Exception ignored) {}

        // Thử file system (đường dẫn tuyệt đối)
        Resource fileResource = new FileSystemResource(serviceAccountPath);
        if (fileResource.exists()) {
            log.debug("Load Firebase service account từ file system: {}", serviceAccountPath);
            return fileResource.getInputStream();
        }

        throw new IOException(STR."Không tìm thấy Firebase service account file: \{serviceAccountPath}");
    }
}
