import 'dart:convert';

import 'package:bodega_mobile/core/configuracion_ticket_service.dart';
import 'package:bodega_mobile/core/lock_service.dart';
import 'package:bodega_mobile/core/offline/offline_models.dart';
import 'package:bodega_mobile/core/offline/offline_sync_manager.dart';
import 'package:bodega_mobile/core/secure_storage_service.dart';
import 'package:bodega_mobile/core/theme_provider.dart';
import 'package:bodega_mobile/core/widgets/solicitar_pin_dialog.dart';
import 'package:bodega_mobile/features/auth/auth_service.dart';
import 'package:bodega_mobile/features/movimientos/mermas_service.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/ventas/venta_en_espera_service.dart';
import 'package:bodega_mobile/features/ventas/venta_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _makeValidJwt({String role = 'ADMIN', String username = 'admin_user'}) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final exp =
      DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/
      1000;
  final payload = base64Url.encode(
    utf8.encode(
      '{"sub":"$username","role":"$role","authorities":["ROLE_$role"],"exp":$exp}',
    ),
  );
  return '$header.$payload.sig';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    SecureStorageService.clearMemoryCache();
    ConfiguracionTicketService.resetSession();
    VentaEnEsperaService.resetSession();
    MermasService.resetSession();
    await LockService().removePin();
  });

  tearDown(() {
    OfflineSyncManager.instance.dispose();
  });

  group('Camino A: Multi-Tenant Isolation & Storage Cleanup Tests', () {
    test('ConfiguracionTicketService saves to tenant-isolated key and clears on logout', () async {
      // Tenant 101
      await SecureStorageService.write('id_bodega', '101');
      const config101 = ConfiguracionTicket(
        numeroQr: '999111222',
        titularQr: 'Bodega San Martin',
      );
      await ConfiguracionTicketService.guardar(config101);

      // Verify stored under tenant-specific key
      final raw101 = await SecureStorageService.read(
        'cajaya_config_ticket_pos_101',
      );
      expect(raw101, isNotNull);
      expect(raw101, contains('999111222'));
      expect(raw101, contains('Bodega San Martin'));

      // Load verifies isolation
      final loaded = await ConfiguracionTicketService.cargar();
      expect(loaded.numeroQr, '999111222');
      expect(loaded.titularQr, 'Bodega San Martin');

      // Logout / clearAuth cleans up tenant key and in-memory ticket config
      await SecureStorageService.clearAuth();
      expect(
        await SecureStorageService.read('cajaya_config_ticket_pos_101'),
        isNull,
      );
      expect(ConfiguracionTicketService.actual.numeroQr, '');
      expect(ConfiguracionTicketService.actual.titularQr, '');
    });

    test(
      'VentaEnEsperaService isolates sales by tenant and clears on logout',
      () async {
        final prefs = await SharedPreferences.getInstance();

        // Tenant 202
        await SecureStorageService.write('id_bodega', '202');
        final venta = VentaEnEspera(
          id: 'VTE-202-01',
          fecha: DateTime.now(),
          etiqueta: 'Cliente Juan Perez',
          items: [
            CartItem(
              producto: Producto(
                idProducto: 1,
                codigo: 'INK-500',
                nombre: 'Inca Kola 500ml',
                precioVenta: 3.50,
                stockActual: 10,
              ),
              cantidad: 2,
            ),
          ],
        );

        await VentaEnEsperaService.ponerEnEspera(venta);
        expect(VentaEnEsperaService.ventas.length, 1);
        expect(prefs.getString('cajaya_ventas_en_espera_202_v1'), isNotNull);

        // Logout
        await SecureStorageService.clearAuth();

        expect(VentaEnEsperaService.ventas, isEmpty);
        expect(VentaEnEsperaService.countNotifier.value, 0);
        expect(prefs.getString('cajaya_ventas_en_espera_202_v1'), isNull);
      },
    );

    test(
      'MermasService isolates historical mermas by tenant and clears on logout',
      () async {
        await SecureStorageService.write('id_bodega', '303');
        final key = 'cajaya_mermas_historico_303_v1';
        await SecureStorageService.write(
          key,
          jsonEncode([
            {
              'idMerma': 'MRM-303-01',
              'idProducto': 10,
              'nombreProducto': 'Pan de Molde',
              'cantidad': 1.0,
              'motivo': 'VENCIMIENTO',
              'costoUnitario': 5.0,
              'costoTotal': 5.0,
              'observaciones': 'Fecha expirada',
              'usuarioResponsable': 'admin_303',
              'fecha': DateTime.now().toIso8601String(),
            },
          ]),
        );

        final mermasService = MermasService();
        final lista = await mermasService.obtenerMermas();
        expect(lista.length, 1);
        expect(lista.first.idMerma, 'MRM-303-01');

        // Logout
        await SecureStorageService.clearAuth();
        expect(await SecureStorageService.read(key), isNull);
        expect(MermasService.mermasRevision.value, 0);
      },
    );
  });

  group('Camino A: SolicitarPinDialog & Backdoor Removal Tests', () {
    testWidgets(
      'SolicitarPinDialog blocks access and prompts configuration when no PIN exists',
      (tester) async {
        expect(await LockService().hasPin(), isFalse);

        bool? autorizacionResultado;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    autorizacionResultado = await SolicitarPinDialog.mostrar(
                      context,
                    );
                  },
                  child: const Text('Autorizar Acción'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Autorizar Acción'));
        await tester.pumpAndSettle();

        // Must display "PIN No Configurado" alert
        expect(find.text('PIN No Configurado'), findsOneWidget);
        expect(
          find.textContaining('Por favor, ingresa a Configuración'),
          findsOneWidget,
        );

        // Tap "Entendido"
        await tester.tap(find.text('Entendido'));
        await tester.pumpAndSettle();

        expect(autorizacionResultado, isFalse);
      },
    );

    testWidgets(
      'SolicitarPinDialog rejects backdoor PINs (1234/0000/9999) when user has another PIN',
      (tester) async {
        // Set legitimate secret PIN
        await LockService().savePin('7890');
        expect(await LockService().hasPin(), isTrue);

        bool? autorizacionResultado;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    autorizacionResultado = await SolicitarPinDialog.mostrar(
                      context,
                    );
                  },
                  child: const Text('Pedir PIN'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Pedir PIN'));
        await tester.pumpAndSettle();

        expect(find.text('Autorización Requerida'), findsOneWidget);

        // Try factory backdoor 1234
        await tester.enterText(find.byType(TextField), '1234');
        await tester.tap(find.text('Autorizar'));
        await tester.pumpAndSettle();

        expect(find.text('PIN incorrecto'), findsOneWidget);
        expect(autorizacionResultado, isNull);

        // Try legitimate PIN
        await tester.enterText(find.byType(TextField), '7890');
        await tester.tap(find.text('Autorizar'));
        await tester.pumpAndSettle();

        expect(autorizacionResultado, isTrue);
      },
    );
  });

  group('Camino A: Role Guarding & Navigation Security Tests', () {
    testWidgets(
      'Non-superadmin (ADMIN / CAJERO) navigating to /superadmin is redirected to /home',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final today = DateTime.now().toIso8601String().substring(0, 10);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(
          'briefing_turno_silenciado_v2_admin_test_$today',
          true,
        );
        await prefs.setBool(
          'briefing_turno_silenciado_v2_superadmin_user_$today',
          true,
        );

        await SecureStorageService.write(
          'jwt_token',
          _makeValidJwt(role: 'ADMIN'),
        );
        await SecureStorageService.write('user_rol', 'ADMIN');
        await SecureStorageService.write('username', 'admin_test');

        final router = GoRouter(
          initialLocation: '/superadmin',
          redirect: (context, state) async {
            final path = state.uri.path;
            final isLoggedIn = await AuthService().isLoggedIn();
            if (!isLoggedIn && path != '/login') return '/login';
            if (isLoggedIn) {
              final role = (await AuthService().getUserRole()).toUpperCase();
              if (path == '/login') {
                return role == 'SUPERADMIN' ? '/superadmin' : '/home';
              }
              if (path == '/superadmin' && role != 'SUPERADMIN') {
                return '/home';
              }
              if (path == '/home' && role == 'SUPERADMIN') {
                return '/superadmin';
              }
            }
            return null;
          },
          routes: [
            GoRoute(
              path: '/login',
              builder: (_, _) => const Scaffold(body: Text('LoginTarget')),
            ),
            GoRoute(
              path: '/home',
              builder: (_, _) => const Scaffold(body: Text('HomeTarget')),
            ),
            GoRoute(
              path: '/superadmin',
              builder: (_, _) => const Scaffold(body: Text('SuperAdminTarget')),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => ThemeProvider(),
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        // Redirected away from /superadmin to /home
        expect(router.routeInformationProvider.value.uri.path, '/home');
        expect(find.text('HomeTarget'), findsOneWidget);
        expect(find.text('SuperAdminTarget'), findsNothing);
      },
    );

    testWidgets(
      'SUPERADMIN navigating to /home or /login is redirected to /superadmin',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final today = DateTime.now().toIso8601String().substring(0, 10);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(
          'briefing_turno_silenciado_v2_superadmin_user_$today',
          true,
        );

        await SecureStorageService.write(
          'jwt_token',
          _makeValidJwt(role: 'SUPERADMIN'),
        );
        await SecureStorageService.write('user_rol', 'SUPERADMIN');
        await SecureStorageService.write('username', 'superadmin_user');

        final router = GoRouter(
          initialLocation: '/home',
          redirect: (context, state) async {
            final path = state.uri.path;
            final isLoggedIn = await AuthService().isLoggedIn();
            if (!isLoggedIn && path != '/login') return '/login';
            if (isLoggedIn) {
              final role = (await AuthService().getUserRole()).toUpperCase();
              if (path == '/login') {
                return role == 'SUPERADMIN' ? '/superadmin' : '/home';
              }
              if (path == '/superadmin' && role != 'SUPERADMIN') {
                return '/home';
              }
              if (path == '/home' && role == 'SUPERADMIN') {
                return '/superadmin';
              }
            }
            return null;
          },
          routes: [
            GoRoute(
              path: '/login',
              builder: (_, _) => const Scaffold(body: Text('LoginTarget')),
            ),
            GoRoute(
              path: '/home',
              builder: (_, _) => const Scaffold(body: Text('HomeTarget')),
            ),
            GoRoute(
              path: '/superadmin',
              builder: (_, _) => const Scaffold(body: Text('SuperAdminTarget')),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => ThemeProvider(),
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        // Redirected from /home to /superadmin
        expect(router.routeInformationProvider.value.uri.path, '/superadmin');
        expect(find.text('SuperAdminTarget'), findsOneWidget);
        expect(find.text('HomeTarget'), findsNothing);
      },
    );
  });

  group('Camino A: OfflineSyncManager discard broken sales test', () {
    test(
      'descartarVentaOffline removes damaged or rejected offline sale',
      () async {
        final syncManager = OfflineSyncManager.instance;
        syncManager.resetSession();

        final venta = OfflineVenta(
          uuid: 'broken-uuid-999',
          localTicket: 'TK-00999',
          fechaCreacion: DateTime.now(),
          clienteNombre: 'Cliente Casual',
          tipoComprobante: 'BOLETA',
          metodoPago: 'EFECTIVO',
          total: 10.0,
          idBodega: 1,
          usuarioRegistro: 'cajero',
          detalles: [],
        );

        await syncManager.enqueueSale(venta);
        expect(syncManager.pendingCount, 1);

        // Discard sale
        final discarded = await syncManager.descartarVentaOffline(
          'broken-uuid-999',
        );
        expect(discarded, isTrue);
        expect(syncManager.pendingCount, 0);

        // Discarding non-existent returns false
        expect(
          await syncManager.descartarVentaOffline('non-existent'),
          isFalse,
        );
      },
    );
  });
}
