#!/usr/bin/env bash
set -e

echo "=========================================================="
echo " CajaYa POS Frontend - Limpieza de Código Muerto y Calidad"
echo "=========================================================="

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo -e "\n1. Descargando dependencias de Flutter..."
flutter pub get

echo -e "\n2. Detectando y Eliminando Código Muerto e Imports Huérfanos..."
dart fix --apply

echo -e "\n3. Aplicando Formato Estándar de Código Dart..."
dart format lib/ test/

echo -e "\n4. Ejecutando Análisis Estático Estricto..."
dart analyze lib/ test/

echo -e "\n5. Ejecutando Suite Completa de Pruebas Unitarias y Widgets..."
flutter test

echo -e "\n=========================================================="
echo " ✅ Frontend 100% Limpio, Sin Código Muerto y Verificado!"
echo "=========================================================="
