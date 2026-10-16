[CmdletBinding()]
param([ValidateSet('prod', 'test')][string]$Environment = 'prod')

$ErrorActionPreference = 'Stop'
$containerName = if ($Environment -eq 'test') { 'SI_test_backend' } else { 'SI_backend_app' }
$postgresName = if ($Environment -eq 'test') { 'SI_test_postgres' } else { 'SI_postgres' }
$volumeName = if ($Environment -eq 'test') { 'backend_test_uploads_data' } else { 'backend_uploads_data' }
$containers = @(docker ps -a --format '{{.Names}}')
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect Docker containers.' }
if ($containers -contains $containerName) {
    $info = @(docker inspect $containerName | ConvertFrom-Json)[0]
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect $containerName" }
    $mounted = @($info.Mounts | Where-Object { $_.Destination -eq '/app/uploads' -and $_.Type -eq 'volume' -and $_.Name -eq $volumeName })
    if ($mounted.Count -ne 1) {
        throw "STOP: $containerName has legacy/unexpected upload storage. Export /app/uploads and migrate it to $volumeName before recreating this container. Do not delete the old container. See backend/UPLOAD_STORAGE.md."
    }
    if ($info.State.Running) {
        $destination = Join-Path $PSScriptRoot "../backups/$Environment-storage"
        & (Join-Path $PSScriptRoot 'backup-upload-storage.ps1') -ContainerName $containerName -PostgresContainer $postgresName -Destination $destination | Out-Host
    }
}
& (Join-Path $PSScriptRoot 'initialize-upload-storage.ps1') -Environment $Environment
