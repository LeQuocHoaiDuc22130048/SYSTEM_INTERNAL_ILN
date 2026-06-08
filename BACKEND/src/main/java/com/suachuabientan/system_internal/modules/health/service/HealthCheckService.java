package com.suachuabientan.system_internal.modules.health.service;

import com.suachuabientan.system_internal.modules.health.dto.HealthCheckResponse;
import com.suachuabientan.system_internal.modules.health.dto.HealthResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class HealthCheckService {
    private final JdbcTemplate jdbcTemplate;
    private final RestTemplate restTemplate;

    @Value("${app.face-recognition.base-url:http://127.0.0.1:5000}")
    private String faceRecognitionBaseUrl;

    @Value("${app.face-recognition.health-path:${FACE_RECOGNITION_HEALTH_PATH:/health}}")
    private String faceRecognitionHealthPath;

    @Value("${app.attendance.backup.directory:${ATTENDANCE_BACKUP_DIRECTORY:./backups/attendance}}")
    private String backupDirectory;

    @Value("${app.health.disk.min-free-bytes:${HEALTH_DISK_MIN_FREE_BYTES:1073741824}}")
    private long minFreeBytes;

    @Value("${app.health.disk.min-free-ratio:${HEALTH_DISK_MIN_FREE_RATIO:0.10}}")
    private double minFreeRatio;

    private Instant startedAt = Instant.now();

    @EventListener(ApplicationReadyEvent.class)
    public void onReady() {
        startedAt = Instant.now();
    }

    public HealthResponse health() {
        Map<String, HealthCheckResponse> checks = new LinkedHashMap<>();
        checks.put("database", database());
        checks.put("faceAiModel", faceAiModel());
        checks.put("diskSpace", diskSpace());

        boolean up = checks.values().stream().allMatch(check -> "UP".equals(check.status()));
        return new HealthResponse(
                up ? "UP" : "DOWN",
                Instant.now(),
                Duration.between(startedAt, Instant.now()).toSeconds(),
                checks);
    }

    private HealthCheckResponse database() {
        try {
            Integer result = jdbcTemplate.queryForObject("SELECT 1", Integer.class);
            if (result != null && result == 1) {
                return HealthCheckResponse.up("Database connection OK", Map.of("query", "SELECT 1"));
            }
            return HealthCheckResponse.down("Database returned unexpected result", Map.of("result", result));
        } catch (Exception error) {
            return HealthCheckResponse.down("Database connection failed", Map.of("error", error.getMessage()));
        }
    }

    @SuppressWarnings("unchecked")
    private HealthCheckResponse faceAiModel() {
        String url = faceRecognitionBaseUrl + normalizePath(faceRecognitionHealthPath);
        try {
            ResponseEntity<Map> response = restTemplate.getForEntity(url, Map.class);
            Map<String, Object> body = response.getBody() == null ? Map.of() : response.getBody();
            if (!response.getStatusCode().is2xxSuccessful()) {
                return HealthCheckResponse.down(
                        "Face AI health endpoint returned non-2xx",
                        Map.of("url", url, "statusCode", response.getStatusCode().value()));
            }
            if (isExplicitlyDown(body)) {
                return HealthCheckResponse.down("Face AI model is not loaded", Map.of("url", url, "response", body));
            }
            return HealthCheckResponse.up("Face AI model health OK", Map.of("url", url, "response", body));
        } catch (RestClientException error) {
            return HealthCheckResponse.down("Face AI health endpoint unavailable", Map.of("url", url, "error", error.getMessage()));
        }
    }

    private HealthCheckResponse diskSpace() {
        try {
            Path path = Path.of(backupDirectory).toAbsolutePath();
            Files.createDirectories(path);
            var store = Files.getFileStore(path);
            long usable = store.getUsableSpace();
            long total = store.getTotalSpace();
            double freeRatio = total <= 0 ? 0 : usable / (double) total;
            Map<String, Object> details = Map.of(
                    "path", path.toString(),
                    "usableBytes", usable,
                    "totalBytes", total,
                    "freeRatio", freeRatio,
                    "minFreeBytes", minFreeBytes,
                    "minFreeRatio", minFreeRatio);
            if (usable < minFreeBytes || freeRatio < minFreeRatio) {
                return HealthCheckResponse.down("Disk space below threshold", details);
            }
            return HealthCheckResponse.up("Disk space OK", details);
        } catch (Exception error) {
            return HealthCheckResponse.down("Disk space check failed", Map.of("error", error.getMessage()));
        }
    }

    private String normalizePath(String path) {
        if (path == null || path.isBlank()) return "/health";
        return path.startsWith("/") ? path : "/" + path;
    }

    private boolean isExplicitlyDown(Map<String, Object> body) {
        Object status = body.get("status");
        if (status instanceof String value && ("DOWN".equalsIgnoreCase(value) || "ERROR".equalsIgnoreCase(value))) {
            return true;
        }
        for (String key : new String[]{"modelLoaded", "faceModelLoaded", "miniFasNetLoaded", "minifasnetLoaded"}) {
            Object value = body.get(key);
            if (value instanceof Boolean loaded && !loaded) return true;
        }
        return false;
    }
}
