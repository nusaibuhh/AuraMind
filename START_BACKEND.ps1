$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $root 'FastAPI')

if (-not (Test-Path '.venv')) {
    Write-Host 'Creating Python virtual environment...' -ForegroundColor Cyan
    python -m venv .venv
}

$python = Join-Path (Get-Location) '.venv\Scripts\python.exe'
& $python -m pip install --upgrade pip
& $python -m pip install -r requirements.txt
Write-Host 'Starting FastAPI at http://127.0.0.1:8000' -ForegroundColor Green
& $python -m uvicorn app:app --reload --host 127.0.0.1 --port 8000
