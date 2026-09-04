package com.suachuabientan.system_internal.modules.update.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.update.dto.AppUpdateInfo;
import com.suachuabientan.system_internal.modules.update.dto.CreateUpdateDto;
import com.suachuabientan.system_internal.modules.update.entity.AppUpdate;
import com.suachuabientan.system_internal.modules.update.service.AppUpdateService;
import com.suachuabientan.system_internal.security.authorization.RoleExpressions;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.net.MalformedURLException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.UUID;

@Tag(name = "App Update", description = "Quản lý cập nhật tự động cho ứng dụng client")
@RestController
@RequestMapping("/api/v1/app-updates")
@RequiredArgsConstructor
public class AppUpdateController {

    private static final Logger log = LoggerFactory.getLogger(AppUpdateController.class);

    private final AppUpdateService appUpdateService;

    @Value("${app.update.latest-version:1.1.3}")
    private String latestVersion;

    @Value("${app.update.changelog:- Cập nhật giao diện mới\n- Sửa lỗi kết nối mạng}")
    private String changelog;

    @Value("${app.update.download-url:/api/v1/app-updates/download/system_internal_v1.1.3.apk}")
    private String downloadUrl;

    @Value("${app.update.mandatory:false}")
    private boolean mandatory;

    @Value("${app.update.release-dir:./releases}")
    private String releaseDir;

    @Value("${app.update.public-base-url:}")
    private String publicBaseUrl;

    @Value("${app.update.ios.bundle-id:com.suachuabientan.systeminternal}")
    private String iosBundleId;

    @Value("${app.update.ios.app-title:System Internal}")
    private String iosAppTitle;

    @Value("${app.update.ios.app-store-url:https://apps.apple.com/app/id6740000000}")
    private String iosAppStoreUrl;

    @Operation(summary = "Kiểm tra phiên bản cập nhật")
    @GetMapping("/check")
    public ResponseEntity<ApiResponse<AppUpdateInfo>> checkUpdate(
            @RequestParam String version,
            @RequestParam(required = false, defaultValue = "android") String platform,
            HttpServletRequest request) {
        AppUpdate latest = appUpdateService.getLatestReleased();
        
        String currentLatestVersion = latest != null ? latest.getVersion() : latestVersion;
        String currentDownloadUrl = latest != null ? latest.getDownloadUrl() : downloadUrl;
        boolean currentMandatory = latest != null ? latest.getMandatory() : mandatory;
        String currentChangelog = latest != null ? latest.getChangelog() : changelog;

        if ("ios".equalsIgnoreCase(platform)) {
            currentDownloadUrl = (iosAppStoreUrl != null && !iosAppStoreUrl.isBlank())
                    ? iosAppStoreUrl
                    : "https://apps.apple.com/app/id6740000000";
        }

        boolean updateAvailable = appUpdateService.isVersionNewer(currentLatestVersion, version);
        String formattedChangelog = currentChangelog != null ? currentChangelog.replace("\\n", "\n") : "";
        AppUpdateInfo updateInfo = new AppUpdateInfo(
            updateAvailable,
            currentLatestVersion,
            currentDownloadUrl,
            currentMandatory,
            formattedChangelog
        );
        return ResponseEntity.ok(ApiResponse.success(updateInfo));
    }

    @Operation(summary = "Tải manifest.plist cho môi trường kiểm thử nội bộ iOS")
    @GetMapping(value = "/ios/manifest.plist", produces = {"application/x-plist;charset=UTF-8", "text/xml;charset=UTF-8", MediaType.APPLICATION_XML_VALUE})
    public ResponseEntity<String> getIosManifest(
            @RequestParam(required = false) String version,
            HttpServletRequest request) {
        AppUpdate latest = appUpdateService.getLatestReleased();
        String targetVersion = (version != null && !version.isBlank())
                ? version
                : (latest != null ? latest.getVersion() : latestVersion);

        String baseUrl = getBaseUrl(request);
        String ipaUrl = baseUrl + "/api/v1/app-updates/download/system_internal_v" + targetVersion + ".ipa";

        String plistXml = """
                <?xml version="1.0" encoding="UTF-8"?>
                <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
                <plist version="1.0">
                <dict>
                    <key>items</key>
                    <array>
                        <dict>
                            <key>assets</key>
                            <array>
                                <dict>
                                    <key>kind</key>
                                    <string>software-package</string>
                                    <key>url</key>
                                    <string>%s</string>
                                </dict>
                            </array>
                            <key>metadata</key>
                            <dict>
                                <key>bundle-identifier</key>
                                <string>%s</string>
                                <key>bundle-version</key>
                                <string>%s</string>
                                <key>kind</key>
                                <string>software</string>
                                <key>title</key>
                                <string>%s</string>
                            </dict>
                        </dict>
                    </array>
                </dict>
                </plist>
                """.formatted(ipaUrl, iosBundleId, targetVersion, iosAppTitle);

        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("application/x-plist;charset=UTF-8"))
                .body(plistXml);
    }

    private String getBaseUrl(HttpServletRequest request) {
        if (publicBaseUrl != null && !publicBaseUrl.isBlank()) {
            return publicBaseUrl.replaceAll("/+$", "");
        }
        if (request == null) {
            return "https://localhost:8080";
        }
        String scheme = request.getHeader("X-Forwarded-Proto");
        if (scheme == null || scheme.isBlank()) {
            scheme = request.getScheme();
        }
        String host = request.getHeader("X-Forwarded-Host");
        if (host == null || host.isBlank()) {
            host = request.getHeader("Host");
            if (host == null || host.isBlank()) {
                int port = request.getServerPort();
                boolean isDefaultPort = ("http".equalsIgnoreCase(scheme) && port == 80)
                        || ("https".equalsIgnoreCase(scheme) && port == 443);
                host = request.getServerName() + (isDefaultPort ? "" : ":" + port);
            }
        }
        return scheme + "://" + host;
    }

    @Operation(summary = "Lấy danh sách các bản cập nhật")
    @GetMapping
    @PreAuthorize(RoleExpressions.ADMIN_OR_ABOVE)
    public ResponseEntity<ApiResponse<List<AppUpdate>>> getAllUpdates() {
        return ResponseEntity.ok(ApiResponse.success(appUpdateService.getAllUpdates()));
    }

    @Operation(summary = "Tạo mới bản cập nhật")
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize(RoleExpressions.ADMIN_OR_ABOVE)
    public ResponseEntity<ApiResponse<AppUpdate>> createUpdate(
            @RequestParam(value = "file", required = false) org.springframework.web.multipart.MultipartFile file,
            @RequestParam("version") String version,
            @RequestParam("changelog") String changelog,
            @RequestParam(value = "downloadUrl", required = false) String downloadUrl,
            @RequestParam(value = "mandatory", defaultValue = "false") boolean mandatory,
            @RequestParam(value = "status", defaultValue = "DRAFT") String status
    ) {
        AppUpdate created = appUpdateService.createUpdate(
            file,
            version,
            changelog,
            downloadUrl,
            mandatory,
            status
        );
        return ResponseEntity.ok(ApiResponse.success(created));
    }

    @Operation(summary = "Phát hành bản cập nhật")
    @PostMapping("/{id}/release")
    @PreAuthorize(RoleExpressions.ADMIN_OR_ABOVE)
    public ResponseEntity<ApiResponse<AppUpdate>> releaseUpdate(@PathVariable UUID id) {
        AppUpdate released = appUpdateService.releaseUpdate(id);
        return ResponseEntity.ok(ApiResponse.success(released));
    }

    @Operation(summary = "Xóa bản cập nhật")
    @DeleteMapping("/{id}")
    @PreAuthorize(RoleExpressions.ADMIN_OR_ABOVE)
    public ResponseEntity<ApiResponse<Void>> deleteUpdate(@PathVariable UUID id) {
        appUpdateService.deleteUpdate(id);
        return ResponseEntity.ok(ApiResponse.success(null));
    }

    @Operation(summary = "Tải file cài đặt client")
    @GetMapping("/download/{filename:.+}")
    public ResponseEntity<Resource> downloadFile(@PathVariable String filename) {
        try {
            Path filePath = Paths.get(releaseDir).resolve(filename).normalize();
            // Prevent path traversal attacks
            if (!filePath.startsWith(Paths.get(releaseDir).normalize())) {
                log.warn("Path traversal attempt blocked: {}", filename);
                return ResponseEntity.status(403).build();
            }

            Resource resource = new UrlResource(filePath.toUri());

            if (resource.exists() && resource.isReadable()) {
                log.info("Downloading release file: {}", filename);
                return ResponseEntity.ok()
                    .contentType(MediaType.APPLICATION_OCTET_STREAM)
                    .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + resource.getFilename() + "\"")
                    .body(resource);
            } else {
                log.warn("Release file not found or not readable: {}", filename);
                return ResponseEntity.notFound().build();
            }
        } catch (MalformedURLException e) {
            log.error("Error path format: {}", filename, e);
            return ResponseEntity.badRequest().build();
        }
    }

    boolean isVersionNewer(String latest, String current) {
        return appUpdateService.isVersionNewer(latest, current);
    }
}
