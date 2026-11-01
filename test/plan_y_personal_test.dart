import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/home/bodega_service.dart';
import 'package:bodega_mobile/features/home/plan_y_personal_sheet.dart';

void main() {
  group('BodegaInfo & Subscription Model Tests', () {
    test('BodegaInfo deserializes subscription fields correctly', () {
      final json = {
        'idBodega': 10,
        'nombreComercial': 'Minimarket Los Andes',
        'rucDni': '20601234567',
        'colorPrimario': '#2563EB',
        'plan': 'PRO',
        'estado': true,
        'fechaVencimientoPlan': '2026-11-15T12:00:00Z',
      };

      final info = BodegaInfo.fromJson(json);

      expect(info.idBodega, 10);
      expect(info.nombreComercial, 'Minimarket Los Andes');
      expect(info.plan, 'PRO');
    });

    test('BodegaInfo defaults plan and active state correctly', () {
      final json = {
        'idBodega': 1,
        'nombreComercial': 'Bodega San José',
        'colorPrimario': '#2563EB',
        'plan': 'BASICO',
        'estado': true,
      };

      final info = BodegaInfo.fromJson(json);

      expect(info.plan, 'BASICO');
      expect(info.estado, isTrue);
    });
  });

  group('PlanYPersonalSheet Widget Security & UI Tests', () {
    testWidgets('Displays Mi Bodega Online and PRO features for PRO plan', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlanYPersonalSheet(
              nombreBodega: 'Bodega Demo',
              plan: 'PRO',
              currentUsername: 'admin1',
              userRol: 'ADMIN',
            ),
          ),
        ),
      );

      await tester.pump();

      // Debería mostrar la sección de Mi Bodega Online y botón Mi Enlace
      expect(find.text('Mi Bodega Online'), findsOneWidget);
      expect(find.text('PRO ONLINE'), findsOneWidget);
      expect(find.text('Mi Enlace'), findsOneWidget);
      expect(find.textContaining('Yape / Plin'), findsOneWidget);
    });

    testWidgets('Displays Activar PRO upgrade card for BASICO plan', (WidgetTester tester) async {
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

      // Debería mostrar Mi Bodega Online con opción de Activar PRO
      expect(find.text('Mi Bodega Online'), findsOneWidget);
      expect(find.text('Activar PRO'), findsOneWidget);
      expect(find.textContaining('Yape / Plin'), findsOneWidget);
    });
  });
}
