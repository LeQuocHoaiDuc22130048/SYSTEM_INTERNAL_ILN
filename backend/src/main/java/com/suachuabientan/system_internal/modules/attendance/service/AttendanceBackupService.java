package com.suachuabientan.system_internal.modules.attendance.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.zip.GZIPInputStream;
import java.util.zip.GZIPOutputStream;

@Slf4j
@Service
@RequiredArgsConstructor
public class AttendanceBackupService {
    private static final DateTimeFormatter FILE_TIME_FORMAT =
            DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss").withZone(ZoneOffset.UTC);

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;
    private final NotificationService notificationService;

    @Value("${app.attendance.backup.enabled:${ATTENDANCE_BACKUP_ENABLED:true}}")
    private boolean enabled;

    @Value("${app.attendance.backup.directory:${ATTENDANCE_BACKUP_DIRECTORY:./backups/attendance}}")
    private String backupDirectory;

    @Value("${app.attendance.backup.retention-days:${ATTENDANCE_BACKUP_RETENTION_DAYS:30}}")
    private int retentionDays;

    @Value("${app.attendance.face.match-threshold}")
    private double faceMatchThreshold;

    @Value("${app.attendance.face.calibration.dataset-version}")
    private String faceCalibrationDatasetVersion;

    @Value("${app.attendance.face.calibration.calibrated-at}")
    private String faceCalibratedAt;

    @Value("${app.attendance.face.calibration.report-path}")
    private String faceCalibrationReportPath;

    @Scheduled(cron = "${app.attendance.backup.cron:${ATTENDANCE_BACKUP_CRON:0 30 2 * * *}}", zone = "Asia/Ho_Chi_Minh")
    @Transactional(readOnly = true)
    public void runScheduledBackup() {
        if (!enabled) {
            log.debug("Attendance critical backup is disabled");
            return;
        }
        try {
            Path backupFile = createBackup();
            purgeOldBackups();
            log.info("Attendance critical backup completed: {}", backupFile.toAbsolutePath());
        } catch (Exception error) {
            log.error("Attendance critical backup failed: {}", error.getMessage(), error);
            notificationService.sendToRoles(
                    List.of(UserRole.SUPER_ADMIN, UserRole.ADMIN),
                    NotificationType.ATTENDANCE_BACKUP_FAILED,
                    "Backup cham cong that bai",
                    "Khong tao duoc backup embedding/log cham cong: " + error.getMessage(),
                    "ATTENDANCE_BACKUP",
                    Instant.now().toString(),
                    true);
        }
    }

    public Path createBackup() throws IOException {
        Path directory = Path.of(backupDirectory);
        Files.createDirectories(directory);

        Instant generatedAt = Instant.now();
        Map<String, Object> payload = Map.of(
                "schemaVersion", 1,
                "generatedAt", generatedAt.toString(),
                "purpose", "attendance-critical-restore",
                "calibration", Map.of(
                        "modelName", "face-embedding",
                        "matchThreshold", faceMatchThreshold,
                        "datasetVersion", faceCalibrationDatasetVersion,
                        "calibratedAt", faceCalibratedAt,
                        "reportPath", faceCalibrationReportPath),
                "tables", Map.of(
                        "employee_face_embeddings", employeeFaceEmbeddings(),
                        "attendance_records", attendanceRecords(),
                        "face_recognition_logs", faceRecognitionLogs()));

        byte[] json = objectMapper.writerWithDefaultPrettyPrinter().writeValueAsBytes(payload);
        byte[] gzipped = gzip(json);
        String checksum = sha256(gzipped);

        String baseName = "attendance-critical-backup-" + FILE_TIME_FORMAT.format(generatedAt);
        Path backupFile = directory.resolve(baseName + ".json.gz");
        Path checksumFile = directory.resolve(baseName + ".sha256");
        Files.write(backupFile, gzipped);
        Files.writeString(checksumFile, checksum + "  " + backupFile.getFileName());

        validateBackupFile(backupFile, checksum);
        return backupFile;
    }

    private List<Map<String, Object>> employeeFaceEmbeddings() {
        return jdbcTemplate.queryForList("""
                SELECT id,
                       employee_code,
                       full_name,
                       role,
                       status,
                       face_encoding,
                       face_enrolled,
                       face_verified_by,
                       updated_at,
                       is_deleted
                FROM users
                WHERE face_encoding IS NOT NULL
                   OR face_enrolled = TRUE
                ORDER BY employee_code NULLS LAST, id
                """);
    }

    private List<Map<String, Object>> attendanceRecords() {
        return jdbcTemplate.queryForList("""
                SELECT id,
                       employee_id,
                       type,
                       check_time,
                       mobile_check_time,
                       confidence_score,
                       device_id,
                       device_log_id,
                       is_valid,
                       note,
                       created_at,
                       updated_at,
                       is_deleted
                FROM attendance_records
                ORDER BY check_time ASC, id
                """);
    }

    private List<Map<String, Object>> faceRecognitionLogs() {
        return jdbcTemplate.queryForList("""
                SELECT id,
                       local_attempt_id,
                       employee_id,
                       employee_name,
                       attempted_by,
                       device_id,
                       model_name,
                       source,
                       outcome,
                       similarity_score,
                       threshold,
                       occurred_at,
                       created_at,
                       is_deleted
                FROM face_recognition_logs
                ORDER BY occurred_at ASC, id
                """);
    }

    private byte[] gzip(byte[] json) throws IOException {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        try (GZIPOutputStream gzip = new GZIPOutputStream(output)) {
            gzip.write(json);
        }
        return output.toByteArray();
    }

    private String sha256(byte[] bytes) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(bytes));
        } catch (NoSuchAlgorithmException error) {
            throw new IllegalStateException("SHA-256 is not available", error);
        }
    }

    private void validateBackupFile(Path backupFile, String expectedChecksum) throws IOException {
        byte[] bytes = Files.readAllBytes(backupFile);
        String actualChecksum = sha256(bytes);
        if (!expectedChecksum.equals(actualChecksum)) {
            throw new IllegalStateException("Backup checksum mismatch for " + backupFile);
        }
        if (bytes.length == 0) {
            throw new IllegalStateException("Backup file is empty: " + backupFile);
        }
        try (GZIPInputStream gzip = new GZIPInputStream(Files.newInputStream(backupFile))) {
            Map<?, ?> parsed = objectMapper.readValue(gzip, Map.class);
            if (!parsed.containsKey("tables")) {
                throw new IllegalStateException("Backup JSON is missing tables section: " + backupFile);
            }
        }
    }

    private void purgeOldBackups() throws IOException {
        if (retentionDays <= 0) return;
        Path directory = Path.of(backupDirectory);
        if (!Files.isDirectory(directory)) return;

        Instant cutoff = Instant.now().minusSeconds(retentionDays * 24L * 60L * 60L);
        try (var stream = Files.list(directory)) {
            stream.filter(path -> path.getFileName().toString().startsWith("attendance-critical-backup-"))
                    .filter(path -> {
                        try {
                            return Files.getLastModifiedTime(path).toInstant().isBefore(cutoff);
                        } catch (IOException error) {
                            log.warn("Cannot read backup mtime: {}", path, error);
                            return false;
                        }
                    })
                    .forEach(path -> {
                        try {
                            Files.deleteIfExists(path);
                        } catch (IOException error) {
                            log.warn("Cannot purge old attendance backup: {}", path, error);
                        }
                    });
        }
    }
}
