import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/home/bodega_service.dart';

void main() {
  setUp(() {
    BodegaService.sugerenciasPendientesNotifier.value = 0;
  });

  testWidgets('ValueListenableBuilder oculta el banner cuando pendientes == 0 y lo muestra cuando > 0',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<int>(
            valueListenable: BodegaService.sugerenciasPendientesNotifier,
            builder: (context, count, _) {
              if (count <= 0) return const SizedBox.shrink();
              return Container(
                key: const ValueKey('banner_sugerencia'),
                child: Text('Tienes $count sugerencia(s) pendientes'),
              );
            },
          ),
        ),
      ),
    );

    // Inicialmente count = 0 -> no se muestra el banner
    expect(find.byKey(const ValueKey('banner_sugerencia')), findsNothing);

    // Simular que llega 1 sugerencia del SuperAdmin
    BodegaService.sugerenciasPendientesNotifier.value = 1;
    await tester.pump();

    // El banner aparece inmediatamente
    expect(find.byKey(const ValueKey('banner_sugerencia')), findsOneWidget);
    expect(find.text('Tienes 1 sugerencia(s) pendientes'), findsOneWidget);

    // El administrador acepta o rechaza la sugerencia -> count pasa a 0
    BodegaService.sugerenciasPendientesNotifier.value = 0;
    await tester.pump();

    // El banner desaparece al instante
    expect(find.byKey(const ValueKey('banner_sugerencia')), findsNothing);
  });
}
