$ErrorActionPreference = 'Stop'
Write-Host 'Starting AuraMind MySQL database with Docker Compose...' -ForegroundColor Cyan
docker compose up -d db
docker compose ps db
Write-Host ''
Write-Host 'MySQL is starting on 127.0.0.1:3306.' -ForegroundColor Green
Write-Host 'If it is not ready yet, wait 15-30 seconds and run this script again.' -ForegroundColor Yellow
