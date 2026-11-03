import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'features/auth/auth_service.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/superadmin/superadmin_dashboard_screen.dart';
import 'features/catalogo/catalogo_publico_screen.dart';
import 'features/legal/libro_reclamaciones_screen.dart';
import 'features/legal/terminos_condiciones_screen.dart';
import 'features/legal/politica_privacidad_screen.dart';
import 'core/theme_provider.dart';
import 'core/api_constants.dart';
import 'core/update_service.dart';

import 'core/api_client.dart';
import 'core/karliz_sound_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConstants.init();
  KarlizSoundService.instance.init();
  UpdateService().checkForUpdatesInBackground();

  ApiClient.onSessionExpired = () {
    LoginScreen.sessionExpiredFlag = true;
    _router.go('/login');
  };

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const BodegaApp(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) async {
    final path = state.uri.path;
    final uriStr = state.uri.toString();
    if (path == '/splash') return null;
    if (path == '/catalogo' || uriStr.startsWith('/catalogo')) return null;
    if (path == '/reclamaciones' || uriStr.startsWith('/reclamaciones')) return null;
    if (path == '/terminos' || uriStr.startsWith('/terminos')) return null;
    if (path == '/privacidad' || uriStr.startsWith('/privacidad')) return null;
    final isLoggedIn = await AuthService().isLoggedIn();
    if (!isLoggedIn && path != '/login') return '/login';
    if (isLoggedIn && path == '/login') {
      final role = await AuthService().getUserRole();
      if (role.toUpperCase() == 'SUPERADMIN') return '/superadmin';
      return '/home';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/superadmin',
      builder: (context, state) => const SuperAdminDashboardScreen(),
    ),
    GoRoute(
      path: '/catalogo',
      builder: (context, state) {
        final tienda = state.uri.queryParameters['tienda'] ?? '';
        return CatalogoPublicoScreen(tiendaSlug: tienda);
      },
    ),
    GoRoute(
      path: '/reclamaciones',
      builder: (context, state) {
        final tienda = state.uri.queryParameters['tienda'] ?? '';
        final idBodegaStr = state.uri.queryParameters['idBodega'];
        final idBodega = idBodegaStr != null ? int.tryParse(idBodegaStr) : null;
        return LibroReclamacionesScreen(
          tiendaNombre: tienda,
          idBodega: idBodega,
        );
      },
    ),
    GoRoute(
      path: '/terminos',
      builder: (context, state) => const TerminosCondicionesScreen(),
    ),
    GoRoute(
      path: '/privacidad',
      builder: (context, state) => const PoliticaPrivacidadScreen(),
    ),
  ],
);

class BodegaApp extends StatelessWidget {
  const BodegaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp.router(
      title: 'CajaYa POS',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.themeMode,
      routerConfig: _router,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
    );
  }
}
