# Migration Rehearsal Before Production

Never run a new migration directly on the production database.

Required flow:

1. Take a fresh production backup.
2. Restore it to a clone/staging database.
3. Run all pending Flyway migrations against the clone.
4. Verify critical data counts and schema.
5. Save the rehearsal report.
6. Only then apply the same migration version to production.

This is especially important for migrations that add columns, rewrite data,
change types, or touch biometric/attendance tables.

## Clone Database

Example PostgreSQL flow:

```bash
pg_dump "$PROD_DATABASE_URL" --format=custom --file=prod-before-migration.dump
createdb system_internal_clone
pg_restore --clean --if-exists --dbname="$CLONE_DATABASE_URL" prod-before-migration.dump
```

Use your managed database snapshot/restore tooling if available.

## Run Rehearsal

From `BACKEND/`:

```powershell
.\scripts\rehearse-migration.ps1 `
  -CloneJdbcUrl "jdbc:postgresql://host:5432/system_internal_clone" `
  -CloneDbUser "clone_user" `
  -CloneDbPassword "clone_password" `
  -PsqlUrl "postgresql://clone_user@host:5432/system_internal_clone" `
  -ReportPath "build/migration-rehearsal-report.txt"
```

Safety guard: the script refuses URLs that look like production. The clone URL
must clearly contain `clone`, `staging`, or `test`.

The script runs:

- `flyway:validate`
- `flyway:migrate`
- `flyway:info`
- verification queries for users, face embeddings, attendance records,
  mobile audit timestamps, face recognition logs, and failed Flyway rows

## Production Apply Gate

Do not apply to production unless the report ends with:

```text
result=PASS
```

Before production migration, record:

- backup file/snapshot id
- clone database name
- rehearsal report path
- expected latest Flyway version
- rollback owner
- maintenance window

After production migration, compare the same critical counts against the
rehearsal report. If counts diverge unexpectedly, stop the rollout and inspect
before deploying the new application version.
