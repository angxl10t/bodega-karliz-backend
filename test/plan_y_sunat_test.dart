import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/home/bodega_service.dart';
import 'package:bodega_mobile/features/home/plan_y_personal_sheet.dart';

void main() {
  group('BodegaInfo & SUNAT Model Tests', () {
    test('BodegaInfo deserializes SUNAT and subscription fields correctly', () {
      final json = {
        'idBodega': 10,
        'nombreComercial': 'Minimarket Los Andes',
        'rucDni': '20601234567',
        'colorPrimario': '#2563EB',
        'plan': 'PRO',
        'estado': true,
        'fechaVencimientoPlan': '2026-11-15T12:00:00Z',
        'facturacionSunatActiva': true,
        'sunatProveedor': 'API Facturador SUNAT Gratuito',
        'sunatRucEmisor': '20601234567',
        'serieBoleta': 'B001',
        'serieFactura': 'F001',
      };

      final info = BodegaInfo.fromJson(json);

      expect(info.idBodega, 10);
      expect(info.nombreComercial, 'Minimarket Los Andes');
      expect(info.plan, 'PRO');
      expect(info.facturacionSunatActiva, isTrue);
      expect(info.sunatProveedor, 'API Facturador SUNAT Gratuito');
      expect(info.sunatRucEmisor, '20601234567');
      expect(info.serieBoleta, 'B001');
      expect(info.serieFactura, 'F001');
    });

    test('BodegaInfo defaults facturacionSunatActiva to false if missing', () {
      final json = {
        'idBodega': 1,
        'nombreComercial': 'Bodega San José',
        'colorPrimario': '#2563EB',
        'plan': 'BASICO',
        'estado': true,
      };

      final info = BodegaInfo.fromJson(json);

      expect(info.facturacionSunatActiva, isFalse);
      expect(info.sunatProveedor, isNull);
    });
  });

  group('PlanYPersonalSheet Widget Security & UI Tests', () {
    testWidgets('Displays protected locked state for CAJERO role', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlanYPersonalSheet(
              nombreBodega: 'Bodega Demo',
              plan: 'PRO',
              currentUsername: 'cajero1',
              userRol: 'CAJERO',
            ),
          ),
        ),
      );

      await tester.pump();

      // Debería mostrar la etiqueta de bloqueo y advertencia para el cajero
      expect(find.text('BLOQUEADO'), findsOneWidget);
      expect(find.textContaining('Protegido por el Administrador'), findsOneWidget);
      // Un cajero no debe ver el botón de configuración directa
      expect(find.text('Configurar Boletas'), findsNothing);
    });

    testWidgets('Displays interactive SUNAT config and Yape button for ADMIN role', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlanYPersonalSheet(
              nombreBodega: 'Bodega Central',
              plan: 'BASICO',
              currentUsername: 'admin_bodega',
              userRol: 'ADMIN',
            ),
          ),
        ),
      );

      await tester.pump();

      // Debería mostrar el botón de configuración SUNAT para ADMIN
      expect(find.text('Configurar Boletas'), findsOneWidget);
      // No debería mostrar la etiqueta de BLOQUEADO para ADMIN
      expect(find.text('BLOQUEADO'), findsNothing);
      // Debería mostrar el botón de renovación / pago con Yape o Plin
      expect(find.textContaining('Yape / Plin'), findsOneWidget);
    });
  });
}
