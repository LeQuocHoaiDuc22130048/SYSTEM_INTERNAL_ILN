$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot\..
& "$PSScriptRoot/prepare-upload-storage.ps1" -Environment test
Write-Host "Starting TEST / DEV Environment..." -ForegroundColor Green
docker compose -p si_test -f docker-compose.test.yml --env-file .env.test up -d --build
if ($LASTEXITCODE -ne 0) { throw 'TEST startup failed.' }
Write-Host "TEST Environment started!" -ForegroundColor Green
Write-Host "Backend API: http://localhost:8081" -ForegroundColor Yellow
Write-Host "Frontend:    http://localhost:5174" -ForegroundColor Yellow
Write-Host "Database:    localhost:5433 (system_internal_test_db)" -ForegroundColor Yellow
Write-Host "MinIO:       http://localhost:9002 (Console: http://localhost:9003)" -ForegroundColor Yellow
