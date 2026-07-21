package com.suachuabientan.system_internal.modules.update.service;

import com.suachuabientan.system_internal.modules.update.entity.AppUpdate;
import com.suachuabientan.system_internal.modules.update.repository.AppUpdateRepository;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.auth.enums.UserStatus;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class AppUpdateService {

    private final AppUpdateRepository appUpdateRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;

    @Value("${app.update.release-dir:./releases}")
    private String releaseDir;

    @Transactional(readOnly = true)
    public List<AppUpdate> getAllUpdates() {
        return appUpdateRepository.findByIsDeletedFalseOrderByCreatedAtDesc();
    }

    @Transactional(readOnly = true)
    public AppUpdate getLatestReleased() {
        List<AppUpdate> released = appUpdateRepository.findLatestReleased();
        return released.isEmpty() ? null : released.get(0);
    }

    @Transactional
    public AppUpdate createUpdate(MultipartFile file, String version, String changelog, String downloadUrl, Boolean mandatory, String status) {
        String resolvedUrl = downloadUrl;
        if (file != null && !file.isEmpty()) {
            resolvedUrl = saveReleaseFile(file, version);
        }

        AppUpdate appUpdate = AppUpdate.builder()
                .version(version)
                .changelog(changelog)
                .downloadUrl(resolvedUrl)
                .mandatory(mandatory != null && mandatory)
                .status(status != null ? status : "DRAFT")
                .build();
        
        if ("RELEASED".equals(status)) {
            appUpdate.setReleasedAt(Instant.now());
        }
        
        AppUpdate saved = appUpdateRepository.save(appUpdate);
        
        if ("RELEASED".equals(status)) {
            triggerMassRelease(saved);
        }
        
        return saved;
    }

    private String saveReleaseFile(MultipartFile file, String version) {
        try {
            String cleanVersion = version.trim().replaceAll("[^0-9.]", "");
            String filename = "system_internal_v" + cleanVersion + ".apk";
            
            Path targetDir = Paths.get(releaseDir).normalize();
            if (!Files.exists(targetDir)) {
                Files.createDirectories(targetDir);
            }
            
            Path targetPath = targetDir.resolve(filename).normalize();
            if (!targetPath.startsWith(targetDir)) {
                throw new IllegalArgumentException("Đường dẫn file không hợp lệ");
            }
            
            Files.copy(file.getInputStream(), targetPath, StandardCopyOption.REPLACE_EXISTING);
            log.info("Đã lưu tệp APK cập nhật: {}", targetPath.toAbsolutePath());
            
            return "/api/v1/app-updates/download/" + filename;
        } catch (IOException e) {
            log.error("Lỗi khi lưu tệp APK cập nhật: {}", e.getMessage(), e);
            throw new RuntimeException("Không thể lưu tệp APK cài đặt: " + e.getMessage());
        }
    }

    @Transactional
    public AppUpdate releaseUpdate(UUID id) {
        AppUpdate appUpdate = appUpdateRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy bản cập nhật: " + id));
        
        if ("RELEASED".equals(appUpdate.getStatus())) {
            return appUpdate; // Already released
        }
        
        appUpdate.setStatus("RELEASED");
        appUpdate.setReleasedAt(Instant.now());
        AppUpdate saved = appUpdateRepository.save(appUpdate);
        
        triggerMassRelease(saved);
        
        return saved;
    }

    private void triggerMassRelease(AppUpdate update) {
        // Send notifications to all active users
        List<UserEntity> activeUsers = userRepository.findByStatusAndIsDeletedFalse(UserStatus.ACTIVE);
        List<UUID> recipientIds = activeUsers.stream()
                .map(UserEntity::getId)
                .toList();
        
        if (recipientIds.isEmpty()) {
            log.info("Không có người dùng active nào để gửi thông báo phát hành bản cập nhật mới");
            return;
        }

        log.info("Bắt đầu phát hành hàng loạt thông báo cập nhật v{} cho {} người dùng", update.getVersion(), recipientIds.size());
        
        try {
            notificationService.sendToUsers(
                    recipientIds,
                    NotificationType.APP_UPDATE,
                    "Có bản cập nhật mới (v" + update.getVersion() + ")",
                    update.getChangelog(),
                    "APP_UPDATE",
                    update.getId().toString(),
                    true
            );
        } catch (Exception e) {
            log.error("Lỗi khi gửi thông báo phát hành hàng loạt: {}", e.getMessage(), e);
        }
    }
}
