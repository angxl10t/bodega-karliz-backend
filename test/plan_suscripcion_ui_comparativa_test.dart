import 'package:bodega_mobile/core/widgets/pago_yape_modal.dart';
import 'package:bodega_mobile/features/home/mi_suscripcion_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('Mi Plan, Suscripción & Comparativa QR Responsive Tests', () {
    testWidgets(
      'MiSuscripcionModal renders without overflow on narrow mobile (340x760) and shows BASICO benefits + comparativa',
      (tester) async {
        tester.view.physicalSize = const Size(340, 760);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => MiSuscripcionModal.show(
                      ctx,
                      nombreBodega:
                          'Bodega & Minimarket Los Ángeles del Sur SAC',
                      planActual: 'BASICO',
                    ),
                    child: const Text('Abrir Mi Plan'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Mi Plan'));
        await tester.pumpAndSettle();

        expect(find.text('Mi Plan y Suscripción'), findsOneWidget);
        expect(find.text('Plan Bodega Básico'), findsOneWidget);
        expect(find.text('INCLUIDO EN TU PLAN BODEGA BÁSICO:'), findsOneWidget);
        expect(
          find.text('COMPARATIVA DETALLADA: BÁSICO VS PRO'),
          findsOneWidget,
        );
        expect(
          find.text('Capacidad de Productos en Inventario'),
          findsOneWidget,
        );
        expect(find.text('Máx. 150'), findsOneWidget);
        expect(find.text('ILIMITADO'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'PagoYapeModal shows clear plan highlights and expands detailed comparison alongside QR without overflow on 340x760',
      (tester) async {
        tester.view.physicalSize = const Size(340, 760);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () =>
                        PagoYapeModal.show(ctx, planInicial: 'BASICO'),
                    child: const Text('Mostrar QR'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Mostrar QR'));
        await tester.pumpAndSettle();

        expect(find.text('Plan Bodega Básico'), findsOneWidget);
        expect(find.text('Plan PRO'), findsOneWidget);
        expect(find.textContaining('Máx. 150 productos'), findsOneWidget);
        expect(find.textContaining('Productos ILIMITADOS'), findsOneWidget);
        expect(
          find.text('Comparativa detallada (Básico vs PRO)'),
          findsOneWidget,
        );
        expect(find.text('Monto exacto a pagar: S/ 39.00'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Expandir la tabla comparativa detallada junto al QR
        await tester.tap(find.text('Comparativa detallada (Básico vs PRO)'));
        await tester.pumpAndSettle();

        expect(find.text('COMPARATIVA DETALLADA DE FUNCIONES'), findsOneWidget);
        expect(
          find.text('Capacidad de Productos en Inventario'),
          findsOneWidget,
        );
        expect(find.text('Detector de Mercadería Hueso'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
