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
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.List;
import java.util.Objects;
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

    public record FileMeta(String downloadUrl, String sha256, long fileSize) {}

    @Transactional(readOnly = true)
    public List<AppUpdate> getAllUpdates() {
        return getAllUpdates(null, null);
    }

    @Transactional(readOnly = true)
    public List<AppUpdate> getAllUpdates(String platform) {
        return getAllUpdates(platform, null);
    }

    @Transactional(readOnly = true)
    public List<AppUpdate> getAllUpdates(String platform, String channel) {
        boolean hasPlatform = platform != null && !platform.isBlank() && !"ALL".equalsIgnoreCase(platform.trim());
        boolean hasChannel = channel != null && !channel.isBlank() && !"ALL".equalsIgnoreCase(channel.trim());

        if (hasPlatform && hasChannel) {
            return appUpdateRepository.findByPlatformIgnoreCaseAndChannelIgnoreCaseAndIsDeletedFalseOrderByCreatedAtDesc(
                    platform.trim(), channel.trim());
        } else if (hasPlatform) {
            return appUpdateRepository.findByPlatformIgnoreCaseAndIsDeletedFalseOrderByCreatedAtDesc(platform.trim());
        } else if (hasChannel) {
            return appUpdateRepository.findByChannelIgnoreCaseAndIsDeletedFalseOrderByCreatedAtDesc(channel.trim());
        }
        return appUpdateRepository.findByIsDeletedFalseOrderByCreatedAtDesc();
    }

    @Transactional(readOnly = true)
    public AppUpdate getLatestReleased() {
        return getLatestReleased("ANDROID", "PRODUCTION");
    }

    @Transactional(readOnly = true)
    public AppUpdate getLatestReleased(String platform) {
        return getLatestReleased(platform, "PRODUCTION");
    }

    @Transactional(readOnly = true)
    public AppUpdate getLatestReleased(String platform, String channel) {
        String targetPlatform = (platform != null && !platform.isBlank()) ? platform.trim().toUpperCase() : "ANDROID";
        String targetChannel = (channel != null && !channel.isBlank()) ? channel.trim().toUpperCase() : "PRODUCTION";

        List<AppUpdate> released = appUpdateRepository.findLatestReleasedByPlatformAndChannel(targetPlatform, targetChannel);
        if (released.isEmpty() && !"PRODUCTION".equals(targetChannel)) {
            // Fallback sang PRODUCTION nếu không có bản release riêng cho channel này
            released = appUpdateRepository.findLatestReleasedByPlatformAndChannel(targetPlatform, "PRODUCTION");
        }
        if (released.isEmpty()) {
            return null;
        }

        AppUpdate highest = released.get(0);
        for (int i = 1; i < released.size(); i++) {
            AppUpdate current = released.get(i);
            if (isVersionNewer(current.getVersion(), highest.getVersion())) {
                highest = current;
            }
        }
        return highest;
    }

    public boolean isMandatory(AppUpdate update, String clientVersion) {
        if (update == null) return false;
        if (Boolean.TRUE.equals(update.getMandatory())) return true;
        if (update.getMinSupportedVersion() != null && !update.getMinSupportedVersion().isBlank() && clientVersion != null) {
            return isVersionNewer(update.getMinSupportedVersion(), clientVersion);
        }
        return false;
    }

    public boolean isVersionNewer(String latest, String current) {
        if (latest == null || current == null) return false;
        
        String lClean = latest.split("\\+")[0].trim().replaceAll("[^0-9.]", "");
        String cClean = current.split("\\+")[0].trim().replaceAll("[^0-9.]", "");

        if (lClean.isEmpty() || cClean.isEmpty()) return false;

        String[] latestParts = lClean.split("\\.");
        String[] currentParts = cClean.split("\\.");

        int length = Math.max(latestParts.length, currentParts.length);
        for (int i = 0; i < length; i++) {
            int lPart = i < latestParts.length && !latestParts[i].isEmpty() ? parsePart(latestParts[i]) : 0;
            int cPart = i < currentParts.length && !currentParts[i].isEmpty() ? parsePart(currentParts[i]) : 0;

            if (lPart > cPart) return true;
            if (lPart < cPart) return false;
        }
        return false;
    }

    private int parsePart(String val) {
        try {
            return Integer.parseInt(val);
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    @Transactional
    public AppUpdate createUpdate(MultipartFile file, String version, String changelog, String downloadUrl, Boolean mandatory, String status) {
        return createUpdate(file, "ANDROID", version, changelog, downloadUrl, mandatory, status, null, "PRODUCTION", null, null);
    }

    @Transactional
    public AppUpdate createUpdate(MultipartFile file, String platform, String version, String changelog, String downloadUrl, Boolean mandatory, String status) {
        return createUpdate(file, platform, version, changelog, downloadUrl, mandatory, status, null, "PRODUCTION", null, null);
    }

    @Transactional
    public AppUpdate createUpdate(
            MultipartFile file,
            String platform,
            String version,
            String changelog,
            String downloadUrl,
            Boolean mandatory,
            String status,
            String minSupportedVersion,
            String channel,
            String manualSha256,
            Long manualFileSize
    ) {
        String normalizedPlatform = (platform != null && "ios".equalsIgnoreCase(platform.trim())) ? "IOS" : 
                ((platform != null && "web".equalsIgnoreCase(platform.trim())) ? "WEB" : "ANDROID");
        String normalizedChannel = (channel != null && !channel.isBlank()) ? channel.trim().toUpperCase() : "PRODUCTION";
        String defaultFilename = buildReleaseFilename(normalizedPlatform, normalizedChannel, version);
        String defaultUrl = "/api/v1/app-updates/download/" + defaultFilename;
        
        String resolvedUrl = (downloadUrl != null && !downloadUrl.trim().isEmpty()) ? downloadUrl.trim() : defaultUrl;
        String resolvedSha256 = manualSha256 != null && !manualSha256.isBlank() ? manualSha256.trim() : null;
        Long resolvedFileSize = manualFileSize;
        boolean hasNewFile = file != null && !file.isEmpty();

        if (hasNewFile) {
            String originalFilename = file.getOriginalFilename();
            if ("IOS".equals(normalizedPlatform)) {
                if (originalFilename == null || !originalFilename.toLowerCase().endsWith(".ipa")) {
                    throw new IllegalArgumentException("Tệp cài đặt cho iOS phải có định dạng .ipa");
                }
            } else if ("ANDROID".equals(normalizedPlatform)) {
                if (originalFilename == null || !originalFilename.toLowerCase().endsWith(".apk")) {
                    throw new IllegalArgumentException("Tệp cài đặt cho Android phải có định dạng .apk");
                }
            }
            FileMeta meta = saveReleaseFile(file, normalizedPlatform, normalizedChannel, version);
            resolvedUrl = meta.downloadUrl();
            resolvedSha256 = meta.sha256();
            resolvedFileSize = meta.fileSize();
        }

        AppUpdate appUpdate = appUpdateRepository.findFirstByVersionAndPlatformIgnoreCaseAndChannelIgnoreCaseAndIsDeletedFalseOrderByCreatedAtDesc(
                        version.trim(), normalizedPlatform, normalizedChannel)
                .orElseGet(() -> AppUpdate.builder()
                        .version(version.trim())
                        .platform(normalizedPlatform)
                        .channel(normalizedChannel)
                        .build());

        boolean urlChanged = appUpdate.getDownloadUrl() != null && !Objects.equals(appUpdate.getDownloadUrl(), resolvedUrl);

        appUpdate.setPlatform(normalizedPlatform);
        appUpdate.setChannel(normalizedChannel);
        appUpdate.setChangelog(changelog);
        appUpdate.setDownloadUrl(resolvedUrl);
        appUpdate.setMandatory(mandatory != null && mandatory);
        appUpdate.setMinSupportedVersion(minSupportedVersion != null && !minSupportedVersion.isBlank() ? minSupportedVersion.trim() : null);

        if (hasNewFile || resolvedSha256 != null || urlChanged) {
            appUpdate.setSha256(resolvedSha256);
        }
        if (hasNewFile || resolvedFileSize != null || urlChanged) {
            appUpdate.setFileSize(resolvedFileSize);
        }

        appUpdate.setStatus(status != null ? status : "DRAFT");
        
        if ("RELEASED".equals(status)) {
            appUpdate.setReleasedAt(Instant.now());
        }
        
        AppUpdate saved = appUpdateRepository.save(appUpdate);
        
        if ("RELEASED".equals(status)) {
            triggerMassRelease(saved);
        }
        
        return saved;
    }

    private String buildReleaseFilename(String platform, String channel, String version) {
        String cleanVersion = version.trim().replaceAll("[^0-9.]", "");
        String ext = "IOS".equalsIgnoreCase(platform) ? ".ipa" : ".apk";
        String channelSuffix = (channel == null || "PRODUCTION".equalsIgnoreCase(channel.trim()))
                ? ""
                : "_" + channel.trim().toLowerCase().replaceAll("[^a-z0-9]", "");
        return "system_internal_v" + cleanVersion + channelSuffix + ext;
    }

    private FileMeta saveReleaseFile(MultipartFile file, String platform, String channel, String version) {
        try {
            String filename = buildReleaseFilename(platform, channel, version);
            String targetDirStr = (releaseDir != null && !releaseDir.isBlank()) ? releaseDir : "./releases";
            
            Path targetDir = Paths.get(targetDirStr).normalize();
            if (!Files.exists(targetDir)) {
                Files.createDirectories(targetDir);
            }
            
            Path targetPath = targetDir.resolve(filename).normalize();
            if (!targetPath.startsWith(targetDir)) {
                throw new IllegalArgumentException("Đường dẫn file không hợp lệ");
            }
            
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            long totalBytes = 0;
            byte[] buffer = new byte[8192];
            int read;
            try (InputStream is = file.getInputStream();
                 OutputStream os = Files.newOutputStream(targetPath)) {
                while ((read = is.read(buffer)) != -1) {
                    digest.update(buffer, 0, read);
                    os.write(buffer, 0, read);
                    totalBytes += read;
                }
            }
            
            byte[] hash = digest.digest();
            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) hexString.append('0');
                hexString.append(hex);
            }
            String sha256 = hexString.toString();
            
            log.info("Đã lưu tệp cài đặt {} [{}] cập nhật: {} (size={} bytes, sha256={})", 
                    platform, channel, targetPath.toAbsolutePath(), totalBytes, sha256);
            
            return new FileMeta("/api/v1/app-updates/download/" + filename, sha256, totalBytes);
        } catch (NoSuchAlgorithmException | IOException e) {
            log.error("Lỗi khi lưu tệp cài đặt cập nhật {}: {}", platform, e.getMessage(), e);
            throw new RuntimeException("Không thể lưu tệp cài đặt: " + e.getMessage());
        }
    }

    @Transactional
    public AppUpdate releaseUpdate(UUID id) {
        AppUpdate appUpdate = appUpdateRepository.findById(id)
                .filter(u -> !Boolean.TRUE.equals(u.getIsDeleted()))
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

    @Transactional
    public AppUpdate rollbackUpdate(UUID id) {
        AppUpdate appUpdate = appUpdateRepository.findById(id)
                .filter(u -> !Boolean.TRUE.equals(u.getIsDeleted()))
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy bản cập nhật: " + id));
        
        appUpdate.setStatus("ROLLED_BACK");
        AppUpdate saved = appUpdateRepository.save(appUpdate);
        log.warn("Đã thu hồi (rollback) bản cập nhật {} [{}] v{} (ID: {})", 
                saved.getPlatform(), saved.getChannel(), saved.getVersion(), saved.getId());
        return saved;
    }

    private void triggerMassRelease(AppUpdate update) {
        String channel = update.getChannel() != null ? update.getChannel().trim().toUpperCase() : "PRODUCTION";
        if (!"PRODUCTION".equals(channel)) {
            log.info("Bỏ qua gửi thông báo hàng loạt cho toàn bộ nhân viên vì bản cập nhật v{} thuộc kênh {}",
                    update.getVersion(), channel);
            return;
        }
        if (userRepository == null || notificationService == null) {
            return;
        }

        // Send notifications to all active users
        List<UserEntity> activeUsers = userRepository.findByStatusAndIsDeletedFalse(UserStatus.ACTIVE);
        List<UUID> recipientIds = activeUsers.stream()
                .map(UserEntity::getId)
                .toList();
        
        if (recipientIds.isEmpty()) {
            log.info("Không có người dùng active nào để gửi thông báo phát hành bản cập nhật mới");
            return;
        }

        String platformLabel = (update.getPlatform() != null && "IOS".equalsIgnoreCase(update.getPlatform())) ? "iOS" : "Android";
        log.info("Bắt đầu phát hành thông báo cập nhật {} v{} cho {} người dùng", 
                platformLabel, update.getVersion(), recipientIds.size());
        
        try {
            notificationService.sendToUsers(
                    recipientIds,
                    NotificationType.APP_UPDATE,
                    "Có bản cập nhật " + platformLabel + " mới (v" + update.getVersion() + ")",
                    update.getChangelog(),
                    "APP_UPDATE",
                    update.getId().toString(),
                    true
            );
        } catch (Exception e) {
            log.error("Lỗi khi gửi thông báo phát hành hàng loạt: {}", e.getMessage(), e);
        }
    }

    @Transactional
    public void deleteUpdate(UUID id) {
        AppUpdate appUpdate = appUpdateRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy bản cập nhật: " + id));
        appUpdate.setIsDeleted(true);
        appUpdateRepository.save(appUpdate);
        log.info("Đã xóa bản cập nhật v{} (ID: {})", appUpdate.getVersion(), id);
    }
}
