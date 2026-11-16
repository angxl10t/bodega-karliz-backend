# ==============================================================================
# Script de Restauración de Emergencia de Base de Datos PostgreSQL (CajaYa POS)
# ==============================================================================
# PRECAUCIÓN: Este script sobrescribirá los datos con el contenido del backup.
# Uso:
#   .\scripts\restore_database.ps1 -BackupFile ".\backups\cajaya_pos_backup_XXXX.sql"
# ==============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$BackupFile,
    [string]$HostName = "aws-1-us-west-2.pooler.supabase.com",
    [int]$Port = 5432,
    [string]$Database = "postgres",
    [string]$Username = "postgres.rmdbcmnoanyqumjlfphy",
    [string]$Password = $env:DB_PASSWORD
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $BackupFile)) {
    throw "El archivo de respaldo no existe: $BackupFile"
}

Write-Host "==========================================================" -ForegroundColor Red
Write-Host "                ALERTA DE RESTAURACION                    " -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Red
Write-Host "Vas a restaurar la base de datos de PRODUCCION: $HostName" -ForegroundColor Yellow
Write-Host "Archivo a aplicar: $BackupFile" -ForegroundColor Cyan
Write-Host "Esta accion sobreescribira los registros actuales con el respaldo." -ForegroundColor Yellow
Write-Host ""

$confirmacion = Read-Host "Escribe 'RESTAURAR' en mayusculas para confirmar la operacion"
if ($confirmacion -ne "RESTAURAR") {
    Write-Host "Operacion cancelada por el usuario. No se realizo ningun cambio." -ForegroundColor Green
    exit 0
}

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

$hasPsql = Get-Command psql -ErrorAction SilentlyContinue
$hasDocker = Get-Command docker -ErrorAction SilentlyContinue

Write-Host ">>> Iniciando restauracion..." -ForegroundColor Cyan

if ($hasPsql) {
    $env:PGPASSWORD = $Password
    & psql -h $HostName -p $Port -U $Username -d $Database -f $BackupFile
} elseif ($hasDocker) {
    $parentDir = Split-Path -Parent (Resolve-Path $BackupFile)
    $baseName = Split-Path -Leaf $BackupFile
    docker run --rm -e "PGPASSWORD=$Password" -v "${parentDir}:/backups" postgres:16-alpine `
        psql -h $HostName -p $Port -U $Username -d $Database -f "/backups/$baseName"
} else {
    throw "No se encontro 'psql' ni 'docker' instalados en este equipo."
}

Write-Host ">>> Base de datos restaurada exitosamente desde $BackupFile!" -ForegroundColor Green
