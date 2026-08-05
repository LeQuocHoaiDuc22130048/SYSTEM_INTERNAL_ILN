Set-Location $PSScriptRoot\..
Write-Host "Starting PROD Environment (Preserving existing data)..." -ForegroundColor Cyan
docker compose -p si_backend -f docker-compose.yml --env-file .env up -d
Write-Host "PROD Environment started!" -ForegroundColor Green
Write-Host "Backend API: http://localhost:8080" -ForegroundColor Yellow
Write-Host "Frontend:    http://localhost:5173" -ForegroundColor Yellow
Write-Host "Database:    localhost:5432 (system_internal_db)" -ForegroundColor Yellow
