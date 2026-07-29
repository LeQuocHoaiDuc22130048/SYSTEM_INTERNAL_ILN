package com.suachuabientan.system_internal.modules.update.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.update.dto.AppUpdateInfo;
import com.suachuabientan.system_internal.modules.update.dto.CreateUpdateDto;
import com.suachuabientan.system_internal.modules.update.entity.AppUpdate;
import com.suachuabientan.system_internal.modules.update.service.AppUpdateService;
import com.suachuabientan.system_internal.security.authorization.RoleExpressions;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
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

    @Operation(summary = "Kiểm tra phiên bản cập nhật")
    @GetMapping("/check")
    public ResponseEntity<ApiResponse<AppUpdateInfo>> checkUpdate(@RequestParam String version) {
        AppUpdate latest = appUpdateService.getLatestReleased();
        
        String currentLatestVersion = latest != null ? latest.getVersion() : latestVersion;
        String currentDownloadUrl = latest != null ? latest.getDownloadUrl() : downloadUrl;
        boolean currentMandatory = latest != null ? latest.getMandatory() : mandatory;
        String currentChangelog = latest != null ? latest.getChangelog() : changelog;

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
