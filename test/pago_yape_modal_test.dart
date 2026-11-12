import 'package:bodega_mobile/core/widgets/pago_yape_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PagoYapeModal Camino A y contacto oficial', () {
    test('Usa el número oficial 981006081 y mantiene activado el modo manual (Camino A)', () {
      expect(PagoYapeModal.officialPhoneLocal, equals('981006081'));
      expect(PagoYapeModal.officialPhoneE164, equals('51981006081'));
      expect(PagoYapeModal.officialYapeDisplay, equals('981 006 081'));
      expect(PagoYapeModal.officialPhoneDisplay, equals('+51 981 006 081'));
      expect(PagoYapeModal.yapeWebhookAutomaticoActivo, isFalse);

      final uri = PagoYapeModal.buildWhatsAppSupportUri('Hola soporte');
      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('wa.me'));
      expect(uri.path, equals('/51981006081'));
      expect(uri.queryParameters['text'], equals('Hola soporte'));
    });

    testWidgets(
      'Muestra número Yape/Plin 981 006 081 y CTA de reporte manual',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 950);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () =>
                        PagoYapeModal.show(ctx, planInicial: 'PRO'),
                    child: const Text('Abrir Pago'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Pago'));
        await tester.pumpAndSettle();

        expect(find.text('Titular: Luis T.'), findsOneWidget);
        expect(find.text('Número YAPE: 981 006 081'), findsOneWidget);
        expect(
          find.text('REGISTRAR COMPROBANTE Y SOLICITAR ACTIVACIÓN'),
          findsOneWidget,
        );

        await tester.tap(find.text('PLIN'));
        await tester.pumpAndSettle();
        expect(find.text('Número PLIN: 981 006 081'), findsOneWidget);
      },
    );
  });
}
