[CmdletBinding()]
param(
    [string]$ContainerName = 'SI_backend_app',
    [string]$PostgresContainer = 'SI_postgres',
    [string]$Destination
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Destination)) {
    $Destination = Join-Path $PSScriptRoot '../backups/persistent-storage'
}
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$backupId = [guid]::NewGuid().ToString('N')
$destinationPath = [System.IO.Path]::GetFullPath($Destination)
$backupPath = Join-Path $destinationPath "$stamp-$backupId"
$archiveInContainer = "/tmp/uploads-backup-$backupId.tar.gz"
$dumpInContainer = "/tmp/database-backup-$backupId.dump"

function Get-ContainerInfo([string]$Name) {
    $raw = docker inspect $Name
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect container $Name" }
    $info = @($raw | ConvertFrom-Json)[0]
    if (-not $info.State.Running) { throw "Container $Name must be running to make a verified backup." }
    return $info
}

$backend = Get-ContainerInfo $ContainerName
$postgres = Get-ContainerInfo $PostgresContainer
$databaseName = ($postgres.Config.Env | Where-Object { $_.StartsWith('POSTGRES_DB=') } | Select-Object -First 1) -replace '^POSTGRES_DB=', ''
$databaseUser = ($postgres.Config.Env | Where-Object { $_.StartsWith('POSTGRES_USER=') } | Select-Object -First 1) -replace '^POSTGRES_USER=', ''
if (-not $databaseName -or -not $databaseUser) { throw 'PostgreSQL database/user could not be determined.' }
New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

try {
    # Capture database references first, then immutable uploaded files. Never redirect binary dumps through PowerShell.
    docker exec $PostgresContainer pg_dump -U $databaseUser -d $databaseName -Fc -f $dumpInContainer
    if ($LASTEXITCODE -ne 0) { throw 'Database backup failed; no deployment should proceed.' }
    docker exec $PostgresContainer pg_restore --list $dumpInContainer | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Database backup verification failed.' }
    docker cp "${PostgresContainer}:$dumpInContainer" (Join-Path $backupPath 'database.dump')
    if ($LASTEXITCODE -ne 0) { throw 'Could not copy database backup to host.' }

    docker exec $ContainerName tar -czf $archiveInContainer -C /app/uploads .
    if ($LASTEXITCODE -ne 0) { throw 'Uploaded file backup failed; no deployment should proceed.' }
    docker exec $ContainerName tar -tzf $archiveInContainer | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Uploaded file archive verification failed.' }
    docker cp "${ContainerName}:$archiveInContainer" (Join-Path $backupPath 'uploads.tar.gz')
    if ($LASTEXITCODE -ne 0) { throw 'Could not copy uploaded file backup to host.' }
    tar.exe -tzf (Join-Path $backupPath 'uploads.tar.gz') | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Host copy of uploaded file backup is invalid.' }

    $files = @('database.dump', 'uploads.tar.gz') | ForEach-Object {
        $path = Join-Path $backupPath $_
        [pscustomobject]@{ Name = $_; Bytes = (Get-Item -LiteralPath $path).Length; SHA256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
    }
    [pscustomobject]@{
        CreatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        BackendContainer = $ContainerName
        UploadMounts = @($backend.Mounts | Where-Object { $_.Destination -eq '/app/uploads' } | Select-Object Type, Name, Destination)
        Files = @($files)
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $backupPath 'manifest.json') -Encoding UTF8
    Write-Host "Verified backup saved to $backupPath"
    # Emit the path for callers; backups are never automatically deleted.
    return $backupPath
}
finally {
    docker exec $ContainerName rm -f -- $archiveInContainer | Out-Null
    docker exec $PostgresContainer rm -f -- $dumpInContainer | Out-Null
}
