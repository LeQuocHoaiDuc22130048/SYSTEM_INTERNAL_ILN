# Attendance Critical Backup

The backend creates a daily gzip JSON backup for the data that is painful to
rebuild:

- `users.face_encoding` and face enrollment metadata
- `attendance_records`
- `face_recognition_logs`
- face model threshold/calibration metadata

Default schedule: every day at `02:30` Asia/Ho_Chi_Minh.

Configuration:

```bash
ATTENDANCE_BACKUP_ENABLED=true
ATTENDANCE_BACKUP_DIRECTORY=/secure/backups/attendance
ATTENDANCE_BACKUP_RETENTION_DAYS=30
ATTENDANCE_BACKUP_CRON="0 30 2 * * *"
```

Each backup creates:

```text
attendance-critical-backup-YYYYMMDD-HHMMSS.json.gz
attendance-critical-backup-YYYYMMDD-HHMMSS.sha256
```

The service validates the backup after writing by checking the SHA-256 digest,
opening the gzip stream, and parsing the JSON payload.

## Restore Drill Before Go-Live

Run this once in staging before production go-live, then repeat after major
schema changes:

1. Create a fresh staging database from migrations.
2. Copy the latest `attendance-critical-backup-*.json.gz` and `.sha256` into a
   secure staging folder.
3. Verify checksum:

   ```bash
   sha256sum -c attendance-critical-backup-YYYYMMDD-HHMMSS.sha256
   ```

4. Decompress and inspect counts:

   ```bash
   gzip -dc attendance-critical-backup-YYYYMMDD-HHMMSS.json.gz > restore.json
   jq '.tables.employee_face_embeddings | length' restore.json
   jq '.tables.attendance_records | length' restore.json
   jq '.tables.face_recognition_logs | length' restore.json
   ```

5. Restore into staging with a controlled import script or SQL loader. Preserve
   employee ids and `face_encoding` exactly; changing ids breaks attendance
   references.
6. Start backend against staging and verify:

   - employee face enrollment count matches source
   - latest attendance day count matches source
   - face model calibration metadata matches the backup
   - a known employee can be recognized without re-enrollment

Do not mark attendance go-live ready until this restore drill passes. Losing
face embeddings means re-enrolling every employee.
