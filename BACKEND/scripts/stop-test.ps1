Set-Location $PSScriptRoot\..
Write-Host "Stopping TEST / DEV Environment..." -ForegroundColor Red
docker compose -p si_test -f docker-compose.test.yml --env-file .env.test down
Write-Host "TEST Environment stopped safely." -ForegroundColor Green
