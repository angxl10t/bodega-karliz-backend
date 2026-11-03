# Script de Verificación CI y Calidad de Código Local (Backend)
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " CajaYa POS Backend - Auditoría de Calidad y Tests Locales" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$backendDir = Split-Path -Parent $PSScriptRoot
Set-Location $backendDir

Write-Host "`n1. Analizando Dependencias y Código Huérfano (mvn dependency:analyze)..." -ForegroundColor Yellow
mvn dependency:analyze -DignoreNonCompile=true

Write-Host "`n2. Compilando Código Fuente con Detección de Advertencias..." -ForegroundColor Yellow
mvn clean compile "-Dmaven.compiler.showWarnings=true" "-Dmaven.compiler.showDeprecation=true"
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Error en la compilación de Java. Corrige los errores antes de continuar." -ForegroundColor Red
    exit 1
}

Write-Host "`n3. Ejecutando Suite Completa de Pruebas Automatizadas..." -ForegroundColor Yellow
mvn test "-Dmaven.test.skip=false"
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Una o más pruebas fallaron en el backend." -ForegroundColor Red
    exit 1
}

Write-Host "`n4. Empaquetando JAR Ejecutable de Producción..." -ForegroundColor Yellow
mvn package "-Dmaven.test.skip=true"
if ($LASTEXITCODE -eq 0) {
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host " ✅ Backend 100% Validado y Listo para Push a GitHub!" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
} else {
    Write-Host "`n❌ Falló el empaquetado del JAR." -ForegroundColor Red
    exit 1
}
