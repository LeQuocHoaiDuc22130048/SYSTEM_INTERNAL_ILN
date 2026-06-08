param(
    [Parameter(Mandatory = $true)]
    [string]$CloneJdbcUrl,

    [Parameter(Mandatory = $true)]
    [string]$CloneDbUser,

    [Parameter(Mandatory = $true)]
    [string]$CloneDbPassword,

    [string]$PsqlUrl,

    [string]$ReportPath = "build/migration-rehearsal-report.txt"
)

$ErrorActionPreference = "Stop"

function Write-Step($Message) {
    Write-Host ""
    Write-Host "==> $Message"
}

function Assert-CloneUrl($Url) {
    $lower = $Url.ToLowerInvariant()
    if ($lower.Contains("prod") -or $lower.Contains("production")) {
        throw "CloneJdbcUrl looks like production. Refusing to run migrations: $Url"
    }
    if (-not ($lower.Contains("clone") -or $lower.Contains("staging") -or $lower.Contains("test"))) {
        throw "CloneJdbcUrl must clearly contain clone/staging/test to avoid production migration mistakes: $Url"
    }
}

function Run-Flyway($Goal) {
    & .\mvnw.cmd -q "flyway:$Goal" `
        "-Dflyway.url=$CloneJdbcUrl" `
        "-Dflyway.user=$CloneDbUser" `
        "-Dflyway.password=$CloneDbPassword" `
        "-Dflyway.locations=filesystem:src/main/resources/db/migration"
    if ($LASTEXITCODE -ne 0) {
        throw "Flyway $Goal failed"
    }
}

function Run-Psql($Sql) {
    if ([string]::IsNullOrWhiteSpace($PsqlUrl)) {
        return "SKIPPED: set -PsqlUrl to run data verification queries"
    }
    $env:PGPASSWORD = $CloneDbPassword
    $result = & psql $PsqlUrl -v ON_ERROR_STOP=1 -Atc $Sql
    if ($LASTEXITCODE -ne 0) {
        throw "psql verification failed: $Sql"
    }
    return ($result -join "`n")
}

Assert-CloneUrl $CloneJdbcUrl

New-Item -ItemType Directory -Force -Path (Split-Path $ReportPath) | Out-Null
$startedAt = (Get-Date).ToUniversalTime().ToString("o")
$report = New-Object System.Collections.Generic.List[string]
$report.Add("Migration rehearsal started_at=$startedAt")
$report.Add("clone_jdbc_url=$CloneJdbcUrl")

Write-Step "Validate migration files on clone"
Run-Flyway "validate"
$report.Add("flyway_validate=PASS")

Write-Step "Apply migrations on clone"
Run-Flyway "migrate"
$report.Add("flyway_migrate=PASS")

Write-Step "Collect Flyway info"
Run-Flyway "info"
$report.Add("flyway_info=PASS")

Write-Step "Verify critical attendance/face data on clone"
$queries = [ordered]@{
    "users_total" = "SELECT COUNT(*) FROM users WHERE is_deleted = false;"
    "face_enrolled_total" = "SELECT COUNT(*) FROM users WHERE face_enrolled = true AND face_encoding IS NOT NULL AND is_deleted = false;"
    "attendance_records_total" = "SELECT COUNT(*) FROM attendance_records WHERE is_deleted = false;"
    "attendance_mobile_time_present" = "SELECT COUNT(*) FROM attendance_records WHERE mobile_check_time IS NOT NULL AND is_deleted = false;"
    "face_recognition_logs_total" = "SELECT CASE WHEN to_regclass('public.face_recognition_logs') IS NULL THEN -1 ELSE (SELECT COUNT(*) FROM face_recognition_logs WHERE is_deleted = false) END;"
    "failed_flyway_migrations" = "SELECT COUNT(*) FROM flyway_schema_history WHERE success = false;"
}

foreach ($entry in $queries.GetEnumerator()) {
    $value = Run-Psql $entry.Value
    $report.Add("$($entry.Key)=$value")
    Write-Host "$($entry.Key)=$value"
}

$failedFlyway = ($report | Where-Object { $_ -like "failed_flyway_migrations=*" }) -replace "failed_flyway_migrations=", ""
if ($failedFlyway -ne "0" -and $failedFlyway -notlike "SKIPPED:*") {
    throw "Clone has failed Flyway migrations"
}

$finishedAt = (Get-Date).ToUniversalTime().ToString("o")
$report.Add("Migration rehearsal finished_at=$finishedAt")
$report.Add("result=PASS")
$report | Set-Content -Path $ReportPath -Encoding UTF8

Write-Step "Migration rehearsal PASS"
Write-Host "Report: $ReportPath"
