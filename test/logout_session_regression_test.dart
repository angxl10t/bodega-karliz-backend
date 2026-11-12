import 'dart:convert';

import 'package:bodega_mobile/core/secure_storage_service.dart';
import 'package:bodega_mobile/core/theme_provider.dart';
import 'package:bodega_mobile/features/auth/auth_service.dart';
import 'package:bodega_mobile/features/auth/login_screen.dart';
import 'package:bodega_mobile/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _makeValidJwt() {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final exp =
      DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/
      1000;
  final payload = base64Url.encode(
    utf8.encode('{"sub":"admin_test","exp":$exp}'),
  );
  return '$header.$payload.sig';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Logout Session & Storage Race Condition Regression', () {
    test('Concurrent read(jwt_token) during clearAuth() never repopulates zombie token cache', () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      SecureStorageService.clearMemoryCache();

      await SecureStorageService.write('jwt_token', _makeValidJwt());
      expect(await AuthService().isLoggedIn(), isTrue);

      // Start clearAuth() and trigger concurrent reads in parallel before delete finishes
      final clearFuture = AuthService().logout();
      final concurrentReads = await Future.wait([
        SecureStorageService.read('jwt_token'),
        AuthService().isLoggedIn(),
        SecureStorageService.read('jwt_token'),
      ]);
      await clearFuture;

      expect(concurrentReads[0], isNull);
      expect(concurrentReads[1], isFalse);
      expect(concurrentReads[2], isNull);
      expect(await SecureStorageService.read('jwt_token'), isNull);
      expect(await AuthService().isLoggedIn(), isFalse);
    });

    testWidgets(
      'Admin logout from HomeScreen navigates to LoginScreen on first try',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        FlutterSecureStorage.setMockInitialValues({});
        SharedPreferences.setMockInitialValues({
          'briefing_turno_silenciado_v2_admin_test_${DateTime.now().toIso8601String().substring(0, 10)}':
              true,
        });
        SecureStorageService.clearMemoryCache();

        await SecureStorageService.write('jwt_token', _makeValidJwt());
        await SecureStorageService.write('user_rol', 'ADMIN');
        await SecureStorageService.write('username', 'admin_test');

        final router = GoRouter(
          initialLocation: '/home',
          redirect: (context, state) async {
            final path = state.uri.path;
            final isLoggedIn = await AuthService().isLoggedIn();
            if (!isLoggedIn && path != '/login') return '/login';
            if (isLoggedIn && path == '/login') return '/home';
            return null;
          },
          routes: [
            GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
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

        expect(find.byType(HomeScreen), findsOneWidget);

        await tester.tap(find.text('Admin'));
        await tester.pumpAndSettle();

        expect(find.text('Cerrar Sesión del Terminal'), findsOneWidget);
        await tester.tap(find.text('Cerrar Sesión del Terminal'));
        await tester.pumpAndSettle();

        expect(find.text('Salir'), findsOneWidget);
        await tester.tap(find.text('Salir'));
        await tester.pumpAndSettle();

        expect(await AuthService().isLoggedIn(), isFalse);
        expect(router.routeInformationProvider.value.uri.path, '/login');
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );
  });
}
