Set-Location $PSScriptRoot\..
Write-Host "Stopping PROD Environment..." -ForegroundColor Red
docker compose -p si_backend -f docker-compose.yml --env-file .env stop
Write-Host "PROD Environment stopped (Data preserved)." -ForegroundColor Green
