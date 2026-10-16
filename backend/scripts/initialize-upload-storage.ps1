[CmdletBinding()]
param([ValidateSet('prod', 'test')][string]$Environment = 'prod')

$ErrorActionPreference = 'Stop'
$volumeName = if ($Environment -eq 'test') { 'backend_test_uploads_data' } else { 'backend_uploads_data' }
$existing = @(docker volume ls --format '{{.Name}}')
if ($LASTEXITCODE -ne 0) { throw 'Cannot list Docker volumes.' }
if ($existing -notcontains $volumeName) {
    docker volume create --label 'com.si.purpose=persistent-uploads' $volumeName | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Cannot create persistent upload volume $volumeName" }
}
Write-Host "Persistent upload volume ready: $volumeName (external; retained by compose down -v)."
