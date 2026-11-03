import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bodega_mobile/features/movimientos/auditoria_ciega_screen.dart';
import 'package:bodega_mobile/features/dashboard/dashboard_bi_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:bodega_mobile/core/widgets/plan_upgrade_modal.dart';
import 'package:bodega_mobile/features/home/mi_bodega_online_modal.dart';

void main() {
  group('Plan PRO Lock & Upgrade Modal Tests', () {
    testWidgets(
      'PlanUpgradeModal renders feature highlights, value list and upgrade buttons',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    PlanUpgradeModal.show(
                      context,
                      featureName: 'Detector de Productos Hueso',
                      featureDescription: 'Identifica al instante qué productos tienen más de 30 días sin ventas para recuperar tu capital.',
                      icon: LucideIcons.archive,
                    );
                  },
                  child: const Text('Abrir Modal'),
                ),
              ),
            ),
          ),
        );

        // Tap to open bottom sheet
        await tester.tap(find.text('Abrir Modal'));
        await tester.pumpAndSettle();

        // Check header and feature title
        expect(find.text('EXCLUSIVO PLAN MINIMARKET PRO'), findsOneWidget);
        expect(find.text('Detector de Productos Hueso'), findsNWidgets(2));
        expect(
          find.textContaining('más de 30 días sin ventas'),
          findsAtLeastNWidgets(1),
        );

        // Check key PRO differentiators
        expect(find.text('Mi Bodega Online'), findsOneWidget);
        expect(find.text('Auditoría Rápida por Pasillo'), findsOneWidget);
        expect(find.text('Termómetro de Meta Diaria'), findsOneWidget);
        expect(find.text('Mapa de Horas Punta & BI'), findsOneWidget);
        expect(
          find.text('Reporte de Cierre al WhatsApp del Dueño'),
          findsOneWidget,
        );
        expect(find.text('Catálogo de Productos Ilimitado'), findsOneWidget);

        // Check action buttons
        expect(
          find.text('Mejorar a Plan PRO con Yape / Plin (S/ 100 /mes)'),
          findsOneWidget,
        );
        expect(
          find.text('Continuar con Plan Bodega Básico (S/ 50 /mes)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'MiBodegaOnlineModal shows lock banner and upgrade CTA when isPro is false',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    MiBodegaOnlineModal.show(
                      context,
                      nombreBodega: 'Bodega Don Pepe',
                      telefonoBodega: '987654321',
                      isPro: false,
                    );
                  },
                  child: const Text('Abrir Mi Bodega'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Mi Bodega'));
        await tester.pumpAndSettle();

        // Check title and lock indicator
        expect(find.text('Mi Bodega Online'), findsOneWidget);
        expect(
          find.textContaining('Esta función es exclusiva del Plan PRO'),
          findsOneWidget,
        );
        expect(
          find.text('Mejorar a Plan PRO con Yape / Plin (S/ 100 /mes)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'MiBodegaOnlineModal shows direct WhatsApp share when isPro is true',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    MiBodegaOnlineModal.show(
                      context,
                      nombreBodega: 'Bodega Don Pepe',
                      telefonoBodega: '987654321',
                      isPro: true,
                    );
                  },
                  child: const Text('Abrir Mi Bodega'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Mi Bodega'));
        await tester.pumpAndSettle();

        expect(find.text('Mi Bodega Online'), findsOneWidget);
        expect(find.text('Compartir Catálogo por WhatsApp'), findsOneWidget);
        expect(find.text('Ver Catálogo como Cliente'), findsOneWidget);
      },
    );

    testWidgets(
      'AuditoriaCiegaScreen renders locked paywall when bodega is on BASICO plan',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({
          'jwt_token': 'fake_jwt',
          'plan_bodega': 'BASICO',
          'user_rol': 'ADMIN',
        });
        SharedPreferences.setMockInitialValues({
          'plan_bodega': 'BASICO',
          'user_rol': 'ADMIN',
        });

        await tester.pumpWidget(
          const MaterialApp(home: AuditoriaCiegaScreen()),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('EXCLUSIVO PLAN MINIMARKET PRO'), findsOneWidget);
        expect(
          find.text('Auditoría Rápida por Pasillo'),
          findsAtLeastNWidgets(1),
        );
        expect(
          find.text('Mejorar a Plan PRO con Yape / Plin (S/ 100 /mes)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'DashboardBiScreen renders locked paywall when bodega is on BASICO plan',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({
          'jwt_token': 'fake_jwt',
          'plan_bodega': 'BASICO',
          'user_rol': 'ADMIN',
        });
        SharedPreferences.setMockInitialValues({
          'plan_bodega': 'BASICO',
          'user_rol': 'ADMIN',
        });

        await tester.pumpWidget(const MaterialApp(home: DashboardBiScreen()));

        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('EXCLUSIVO PLAN MINIMARKET PRO'), findsOneWidget);
        expect(
          find.text('Módulo de Analítica & Business Intelligence'),
          findsOneWidget,
        );
        expect(
          find.text('Mejorar a Plan PRO con Yape / Plin (S/ 100 /mes)'),
          findsOneWidget,
        );
      },
    );
  });
}
