import 'package:bodega_mobile/core/secure_storage_service.dart';
import 'package:bodega_mobile/core/theme.dart';
import 'package:bodega_mobile/features/auth/auth_service.dart';
import 'package:bodega_mobile/features/configuracion/modal_generar_codigo_terminal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class MockAuthServiceTerminal extends AuthService {
  bool solicitarCodigoLlamado = false;
  bool revocarLlamado = false;

  @override
  Future<Map<String, dynamic>> solicitarCodigoVinculacion() async {
    solicitarCodigoLlamado = true;
    return {
      'codigo': '847291',
      'expiraEnSegundos': 600,
      'nombreBodega': 'Bodega Central',
      'idBodega': 1,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> listarTerminales() async {
    return [
      {
        'idTerminal': 101,
        'nombre': 'Terminal Caja 1',
        'deviceModel': 'Sunmi POS',
        'fechaVinculacion': '2026-11-20T10:00:00Z',
        'estado': true,
      },
      {
        'idTerminal': 102,
        'nombre': 'Tablet Mozo',
        'deviceModel': 'Samsung Tab',
        'fechaVinculacion': '2026-11-19T10:00:00Z',
        'estado': false,
      },
    ];
  }

  @override
  Future<bool> revocarTerminal(int idTerminal) async {
    revocarLlamado = true;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Terminal Security & Device Pairing Unit Tests', () {
    test('desvincularTerminal limpia todas las credenciales de terminal en SecureStorage', () async {
      await SecureStorageService.write('terminal_token', 'term_secret_123');
      await SecureStorageService.write('terminal_id_bodega', '1');
      await SecureStorageService.write('terminal_nombre_bodega', 'Mi Tienda');
      await SecureStorageService.write('terminal_nombre', 'Caja 1');
      await SecureStorageService.write('terminal_id', '99');

      expect(await AuthService.getTerminalToken(), 'term_secret_123');
      expect(await AuthService.getTerminalIdBodega(), '1');
      expect(await AuthService.getTerminalNombreBodega(), 'Mi Tienda');
      expect(await AuthService.getTerminalNombre(), 'Caja 1');

      await AuthService.desvincularTerminal();

      expect(await AuthService.getTerminalToken(), isNull);
      expect(await AuthService.getTerminalIdBodega(), isNull);
      expect(await AuthService.getTerminalNombreBodega(), isNull);
      expect(await AuthService.getTerminalNombre(), isNull);
    });

    testWidgets(
      'ModalGenerarCodigoTerminal genera y muestra el código OTP de 6 dígitos con cuenta regresiva',
      (tester) async {
        final mockAuth = MockAuthServiceTerminal();
        bool cerrado = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    ModalGenerarCodigoTerminal.show(
                      context,
                      authService: mockAuth,
                      onCerrar: () => cerrado = true,
                    );
                  },
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();

        expect(mockAuth.solicitarCodigoLlamado, isTrue);
        expect(find.text('Vincular Terminal POS'), findsOneWidget);
        expect(find.text('847291'), findsOneWidget);
        expect(find.textContaining('Expira en'), findsOneWidget);
        expect(find.text('Copiar'), findsOneWidget);
        expect(find.text('Nuevo Código'), findsOneWidget);
        expect(find.text('Listo / Cerrar'), findsOneWidget);

        await tester.tap(find.text('Listo / Cerrar'));
        await tester.pumpAndSettle();

        expect(cerrado, isTrue);
      },
    );
  });
}
