#!/usr/bin/env bash
set -e

echo "=========================================================="
echo " CajaYa POS Backend - Auditoría de Calidad y Tests Locales"
echo "=========================================================="

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo -e "\n1. Analizando Dependencias y Código Huérfano..."
mvn dependency:analyze -DignoreNonCompile=true || true

echo -e "\n2. Compilando Código Fuente con Detección de Advertencias..."
mvn clean compile -Dmaven.compiler.showWarnings=true -Dmaven.compiler.showDeprecation=true

echo -e "\n3. Ejecutando Suite Completa de Pruebas Automatizadas..."
mvn test -Dmaven.test.skip=false

echo -e "\n4. Empaquetando JAR Ejecutable de Producción..."
mvn package -Dmaven.test.skip=true

echo -e "\n=========================================================="
echo " ✅ Backend 100% Validado y Listo para Push a GitHub!"
echo "=========================================================="
