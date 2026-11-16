# ==============================================================================
# Script de Respaldo Local / Manual de Base de Datos PostgreSQL (CajaYa POS)
# ==============================================================================
# Uso:
#   .\scripts\backup_database.ps1
#   .\scripts\backup_database.ps1 -Password "tu_password_supabase"
# ==============================================================================

param(
    [string]$HostName = "aws-1-us-west-2.pooler.supabase.com",
    [int]$Port = 5432,
    [string]$Database = "postgres",
    [string]$Username = "postgres.rmdbcmnoanyqumjlfphy",
    [string]$Password = $env:DB_PASSWORD,
    [string]$OutputDir = "$PSScriptRoot\..\backups"
)

$ErrorActionPreference = "Stop"

# Si no se pasó contraseña por parámetro ni por variable de entorno, intentar leerla de .env
if (-not $Password -and (Test-Path "$PSScriptRoot\..\.env")) {
    $envContent = Get-Content "$PSScriptRoot\..\.env"
    foreach ($line in $envContent) {
        if ($line -match "^DB_PASSWORD=(.+)$") {
            $Password = $matches[1].Trim()
            break
        }
    }
}

if (-not $Password) {
    $Password = Read-Host "Ingresa la contrasena de la base de datos Supabase" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$filename = "cajaya_pos_backup_$timestamp.sql"
$filepath = Join-Path $OutputDir $filename

Write-Host ">>> Iniciando respaldo de CajaYa POS ($HostName:$Port/$Database)..." -ForegroundColor Cyan

# Detectar método de ejecución: pg_dump nativo o Docker container
$hasPgDump = Get-Command pg_dump -ErrorAction SilentlyContinue
$hasDocker = Get-Command docker -ErrorAction SilentlyContinue

if ($hasPgDump) {
    Write-Host ">>> Utilizando cliente pg_dump local..." -ForegroundColor Green
    $env:PGPASSWORD = $Password
    & pg_dump -h $HostName -p $Port -U $Username -d $Database --no-owner --no-privileges --clean --if-exists -f $filepath
} elseif ($hasDocker) {
    Write-Host ">>> pg_dump local no detectado. Utilizando contenedor Docker postgres:16-alpine..." -ForegroundColor Green
    docker run --rm -e "PGPASSWORD=$Password" -v "${OutputDir}:/backups" postgres:16-alpine `
        pg_dump -h $HostName -p $Port -U $Username -d $Database --no-owner --no-privileges --clean --if-exists -f "/backups/$filename"
} else {
    Write-Host ">>> AVISO: No se encontro 'pg_dump' ni 'docker' instalados en esta maquina Windows." -ForegroundColor Yellow
    Write-Host ">>> NOTA: Los respaldos ya estan 100% automatizados en GitHub Actions todas las noches." -ForegroundColor Cyan
    Write-Host ">>> Para respaldos locales, instala PostgreSQL Tools o Docker Desktop." -ForegroundColor Gray
    exit 0
}

if (Test-Path $filepath) {
    $size = (Get-Item $filepath).Length
    Write-Host ">>> Respaldo generado con exito: $filename ($([math]::Round($size / 1MB, 2)) MB)" -ForegroundColor Green
    Write-Host ">>> Ubicacion: $filepath" -ForegroundColor Gray
}
