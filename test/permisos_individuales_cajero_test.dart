import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bodega_mobile/core/permisos_cajero_service.dart';
import 'package:bodega_mobile/core/theme.dart';
import 'package:bodega_mobile/core/theme_provider.dart';
import 'package:bodega_mobile/features/configuracion/configuracion_screen.dart';
import 'package:bodega_mobile/features/home/bodega_service.dart';
import 'package:bodega_mobile/features/home/usuarios_service.dart';

Widget _createConfiguracionScreen() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.buildLightTheme(),
      home: const ConfiguracionScreen(tabInicial: ConfiguracionTab.usuarios),
    ),
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'jwt_token': 'fake_token',
      'user_rol': 'ADMIN',
      'username': 'admin_boss',
      'id_bodega': '1',
      'plan_bodega': 'PRO',
    });
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'fake_token',
      'user_rol': 'ADMIN',
      'username': 'admin_boss',
      'id_bodega': '1',
      'plan_bodega': 'PRO',
    });

    PermisosCajeroService.resetMemory();

    BodegaService.setMockMiBodega(
      BodegaInfo(
        idBodega: 1,
        nombreComercial: 'Bodega Karliz',
        rucDni: '20601234567',
        direccion: 'Av. Perú 123',
        telefono: '987654321',
        colorPrimario: '#2563EB',
        lemaComercial: 'Tu tienda de confianza',
        plan: 'PRO',
        estado: true,
        catalogoAbierto: true,
        deliveryActivo: true,
      ),
    );

    UsuariosService.setMockUsuarios([
      UsuarioItem(
        idUsuario: 1,
        username: 'admin_boss',
        nombreCompleto: 'Dueño Administrador',
        rol: 'ADMIN',
        estado: true,
      ),
      UsuarioItem(
        idUsuario: 2,
        username: 'juan_cajero',
        nombreCompleto: 'Juan Regular',
        rol: 'CAJERO',
        estado: true,
      ),
      UsuarioItem(
        idUsuario: 3,
        username: 'maria_confianza',
        nombreCompleto: 'María Encargada',
        rol: 'CAJERO',
        estado: true,
      ),
    ]);
  });

  tearDown(() {
    BodegaService.clearCache();
    UsuariosService.setMockUsuarios(null);
    PermisosCajeroService.resetMemory();
  });

  group('Permisos Individuales de Cajero Tests', () {
    test('PermisosCajeroService permite guardar y resolver permisos diferenciados por usuario', () async {
      // 1. Configurar política por defecto de la tienda: cajero estándar (NO modifica precios)
      await PermisosCajeroService.guardarPermisos(
        const PermisosCajero(
          modificarPreciosVenta: false,
          verCostosYMargen: false,
          aplicarDescuentosManuales: true,
          anularVentasSinPin: false,
        ),
        bodegaId: '1',
      );

      // 2. Personalizar a maria_confianza para que SÍ pueda modificar precios y ver costos
      await PermisosCajeroService.guardarPermisosUsuario(
        'maria_confianza',
        const PermisosCajero(
          modificarPreciosVenta: true,
          verCostosYMargen: true,
          aplicarDescuentosManuales: true,
          anularVentasSinPin: true,
        ),
        bodegaId: '1',
      );

      expect(
        await PermisosCajeroService.tienePermisosPersonalizados(
          'maria_confianza',
          bodegaId: '1',
        ),
        isTrue,
      );
      expect(
        await PermisosCajeroService.tienePermisosPersonalizados(
          'juan_cajero',
          bodegaId: '1',
        ),
        isFalse,
      );

      // 3. Evaluar permisos de maria_confianza
      final permisosMaria = await PermisosCajeroService.obtenerPermisos(
        bodegaId: '1',
        username: 'maria_confianza',
        forceRefresh: true,
      );
      expect(permisosMaria.modificarPreciosVenta, isTrue);
      expect(permisosMaria.verCostosYMargen, isTrue);

      // 4. Evaluar permisos de juan_cajero (usa los de la tienda)
      final permisosJuan = await PermisosCajeroService.obtenerPermisos(
        bodegaId: '1',
        username: 'juan_cajero',
        forceRefresh: true,
      );
      expect(permisosJuan.modificarPreciosVenta, isFalse);
      expect(permisosJuan.verCostosYMargen, isFalse);

      // 5. Eliminar personalización de maria_confianza y verificar que hereda de la tienda
      await PermisosCajeroService.eliminarPermisosUsuario(
        'maria_confianza',
        bodegaId: '1',
      );
      expect(
        await PermisosCajeroService.tienePermisosPersonalizados(
          'maria_confianza',
          bodegaId: '1',
        ),
        isFalse,
      );

      final permisosMariaReset = await PermisosCajeroService.obtenerPermisos(
        bodegaId: '1',
        username: 'maria_confianza',
        forceRefresh: true,
      );
      expect(permisosMariaReset.modificarPreciosVenta, isFalse);
    });

    testWidgets(
      'UI: Abre modal de permisos individuales para un cajero y permite personalizarlo',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 850);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(_createConfiguracionScreen());
        await tester.pumpAndSettle();

        // Verificar que ambos cajeros aparecen en la lista con badge de permisos de tienda
        expect(find.text('Juan Regular'), findsOneWidget);
        expect(find.text('María Encargada'), findsOneWidget);
        expect(find.text('Permisos de Tienda'), findsNWidgets(2));

        // Abrir modal de permisos individuales para María
        final btnPermisosMaria = find.byKey(
          const Key('btnPermisos_maria_confianza'),
        );
        expect(btnPermisosMaria, findsOneWidget);
        await tester.tap(btnPermisosMaria);
        await tester.pumpAndSettle();

        // Verificar título del modal
        expect(find.text('Permisos de @maria_confianza'), findsOneWidget);

        // Activar switch de personalización
        final switchPersonalizar = find.byKey(
          const Key('switchPersonalizarCajero'),
        );
        expect(switchPersonalizar, findsOneWidget);
        await tester.tap(switchPersonalizar);
        await tester.pumpAndSettle();

        // Aplicar preset Encargado
        final presetEncargado = find.byKey(const Key('preset_encargado'));
        expect(presetEncargado, findsOneWidget);
        await tester.tap(presetEncargado);
        await tester.pumpAndSettle();

        // Guardar cambios en el modal
        final btnGuardar = find.byKey(
          const Key('btnGuardarPermisosIndividuales'),
        );
        expect(btnGuardar, findsOneWidget);
        await tester.tap(btnGuardar);
        await tester.pumpAndSettle();

        // El modal se cierra y el badge de María cambia a "Permisos Personalizados"
        expect(find.text('Permisos de @maria_confianza'), findsNothing);
        expect(find.text('Permisos Personalizados'), findsOneWidget);
        expect(
          find.text('Permisos de Tienda'),
          findsOneWidget,
        ); // Juan sigue con permisos de tienda
      },
    );
  });
}
