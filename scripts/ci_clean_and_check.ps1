# Script de Limpieza Automática de Código Muerto y Verificación CI (Frontend)
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " CajaYa POS Frontend - Limpieza de Código Muerto y Calidad" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$frontendDir = Split-Path -Parent $PSScriptRoot
Set-Location $frontendDir

Write-Host "`n1. Descargando dependencias de Flutter (flutter pub get)..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error al obtener dependencias." -ForegroundColor Red
    exit 1
}

Write-Host "`n2. Detectando y Eliminando Código Muerto e Imports Huérfanos (dart fix --apply)..." -ForegroundColor Yellow
dart fix --apply

Write-Host "`n3. Aplicando Formato Estándar de Código Dart (dart format)..." -ForegroundColor Yellow
dart format lib/ test/

Write-Host "`n4. Ejecutando Análisis Estático Estricto (dart analyze)..." -ForegroundColor Yellow
dart analyze lib/ test/
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Se encontraron advertencias o errores en el análisis estático." -ForegroundColor Red
    exit 1
}

Write-Host "`n5. Ejecutando Suite Completa de Pruebas Unitarias y Widgets (flutter test)..." -ForegroundColor Yellow
flutter test
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Una o más pruebas fallaron." -ForegroundColor Red
    exit 1
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " ✅ Frontend 100% Limpio, Sin Código Muerto y Verificado!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
