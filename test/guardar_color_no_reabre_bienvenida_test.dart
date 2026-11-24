import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bodega_mobile/core/widgets/briefing_turno_modal.dart';
import 'package:bodega_mobile/features/auth/auth_service.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'jwt_token': 'fake_token',
      'user_rol': 'ADMIN',
      'username': 'carlos_pos',
      'id_bodega': '1',
      'plan_bodega': 'PRO',
    });
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'fake_token',
      'user_rol': 'ADMIN',
      'username': 'carlos_pos',
      'id_bodega': '1',
      'plan_bodega': 'PRO',
    });
    BriefingTurnoModal.resetSession();
  });

  tearDown(() {
    BriefingTurnoModal.resetSession();
  });

  group('BriefingTurnoModal Session Guard Tests', () {
    testWidgets(
      'showIfNeeded se muestra solo una vez en la sesión y no se repite',
      (tester) async {
        final keyModal = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                key: keyModal,
                body: ElevatedButton(
                  onPressed: () {
                    BriefingTurnoModal.showIfNeeded(
                      ctx,
                      username: 'carlos_pos',
                      userRol: 'ADMIN',
                      nombreBodega: 'Bodega Karliz',
                    );
                  },
                  child: const Text('Trigger Briefing'),
                ),
              ),
            ),
          ),
        );

        // Primera llamada: se abre el modal
        await tester.tap(find.text('Trigger Briefing'));
        await tester.pumpAndSettle();

        expect(find.byType(BriefingTurnoModal), findsOneWidget);
        expect(find.text('¡Hola, carlos_pos!'), findsOneWidget);

        // Cerramos el modal usando el botón X
        final btnCerrar = find.byTooltip('Cerrar Briefing');
        expect(btnCerrar, findsOneWidget);
        await tester.tap(btnCerrar);
        await tester.pumpAndSettle();

        expect(find.byType(BriefingTurnoModal), findsNothing);

        // Segunda llamada en la misma sesión (como cuando el usuario guarda un color o configuración)
        await tester.tap(find.text('Trigger Briefing'));
        await tester.pumpAndSettle();

        // No debe volver a abrirse en la misma sesión
        expect(find.byType(BriefingTurnoModal), findsNothing);
      },
    );

    testWidgets(
      'resetSession al cerrar sesión permite mostrar el briefing en el próximo inicio',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    BriefingTurnoModal.showIfNeeded(
                      ctx,
                      username: 'carlos_pos',
                      userRol: 'ADMIN',
                      nombreBodega: 'Bodega Karliz',
                    );
                  },
                  child: const Text('Trigger Briefing'),
                ),
              ),
            ),
          ),
        );

        // Primera apertura
        await tester.tap(find.text('Trigger Briefing'));
        await tester.pumpAndSettle();
        expect(find.byType(BriefingTurnoModal), findsOneWidget);

        // Cierre
        await tester.tap(find.byTooltip('Cerrar Briefing'));
        await tester.pumpAndSettle();
        expect(find.byType(BriefingTurnoModal), findsNothing);

        // Simular logout
        await AuthService().logout();

        // Nueva sesión iniciada
        await tester.tap(find.text('Trigger Briefing'));
        await tester.pumpAndSettle();

        // Debe permitir abrir en la nueva sesión
        expect(find.byType(BriefingTurnoModal), findsOneWidget);
      },
    );
  });
}
