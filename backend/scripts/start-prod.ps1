$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot\..
& "$PSScriptRoot/prepare-upload-storage.ps1" -Environment prod
Write-Host "Starting PROD Environment (Preserving existing data)..." -ForegroundColor Cyan
docker compose -p si_backend -f docker-compose.yml --env-file .env up -d
if ($LASTEXITCODE -ne 0) { throw 'PROD startup failed.' }
Write-Host "PROD Environment started!" -ForegroundColor Green
Write-Host "Backend API: http://localhost:8080" -ForegroundColor Yellow
Write-Host "Frontend:    http://localhost:5173" -ForegroundColor Yellow
Write-Host "Database:    localhost:5432 (system_internal_db)" -ForegroundColor Yellow
