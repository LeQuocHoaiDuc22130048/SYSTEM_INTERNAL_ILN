# Persistent uploaded images

The backend stores banner images in `/app/uploads/banners`. Compose mounts
`/app/uploads` from an external Docker volume: `backend_uploads_data` in production
and `backend_test_uploads_data` in test. Container rebuilds/recreation and
`docker compose down -v` retain these external volumes.

Use `scripts/start-prod.ps1` or `scripts/start-test.ps1` to start/update the stack.
They initialize the volume and, when the protected backend is running, back up
PostgreSQL and uploads before proceeding. Backup failure stops deployment.
Legacy containers without the expected upload volume stop deployment as well.
Do not remove such a container: export its uploads, back up its database, seed
the new volume, and verify file checksums before recreating it.

## Manual backup

From the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/backup-upload-storage.ps1
```

Default destination: `backend/backups/persistent-storage/<UTC timestamp>-<id>`.
Startup backups use `backend/backups/prod-storage` or `test-storage`. Each backup
contains `database.dump`, `uploads.tar.gz`, and `manifest.json` with SHA256 hashes.
The script validates the database dump catalog and archive readability. It does
not delete older backups. There is no daily backup scheduler installed.

Before restoring, verify both hashes against the manifest. Restore the database
dump into a separate PostgreSQL database first using `pg_restore`, extract uploads
into a separate empty volume, and verify image contents and database references.
Switch production only after verification; retain the original data and backups.
The database and file backup are sequential, so pause upload/deletion activity
when an exact matching snapshot is required.

Backups are ignored by Git and live outside Docker storage. Copy them to another
disk or machine to cover host disk failure. Explicit volume deletion or a Docker
factory reset can still remove the live volume.

## Recovery verified on 2026-10-16

Recovered the three missing original banner JPGs from the public image URLs,
validated them, and restored them without changing database records. A database
backup was restored successfully in an isolated temporary PostgreSQL container.
After migrating uploads to the external volume and recreating the backend, all
three local website image URLs returned HTTP 200 with matching SHA256 hashes.
