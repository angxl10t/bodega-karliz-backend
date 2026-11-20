import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bodega_mobile/core/theme.dart';
import 'package:bodega_mobile/core/theme_provider.dart';
import 'package:bodega_mobile/features/configuracion/configuracion_screen.dart';
import 'package:bodega_mobile/features/home/bodega_service.dart';
import 'package:bodega_mobile/features/home/usuarios_service.dart';

Widget _createConfiguracionScreen({
  ConfiguracionTab tabInicial = ConfiguracionTab.tienda,
  VoidCallback? onConfigSaved,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.buildLightTheme(),
      home: ConfiguracionScreen(
        tabInicial: tabInicial,
        onConfigSaved: onConfigSaved,
      ),
    ),
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'jwt_token': 'fake_token',
      'user_rol': 'ADMIN',
      'id_bodega': '1',
      'plan_bodega': 'PRO',
    });
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'fake_token',
      'user_rol': 'ADMIN',
      'id_bodega': '1',
      'plan_bodega': 'PRO',
    });

    BodegaService.setMockMiBodega(
      BodegaInfo(
        idBodega: 1,
        nombreComercial: 'Bodega San Martín',
        rucDni: '20601234567',
        direccion: 'Av. San Martín 450',
        telefono: '987654321',
        colorPrimario: '#2563EB',
        lemaComercial: '¡Gracias por su compra!',
        plan: 'PRO',
        estado: true,
        catalogoAbierto: true,
        deliveryActivo: true,
      ),
    );

    UsuariosService.setMockUsuarios([
      UsuarioItem(
        idUsuario: 1,
        username: 'santiago',
        nombreCompleto: 'Santiago Morales',
        rol: 'ADMIN',
        estado: true,
      ),
      UsuarioItem(
        idUsuario: 2,
        username: 'karla',
        nombreCompleto: 'Karla Cueva',
        rol: 'CAJERO',
        estado: true,
      ),
    ]);
  });

  tearDown(() {
    BodegaService.clearCache();
    UsuariosService.setMockUsuarios(null);
  });

  group('Configuración & Tienda Calma Visual Tests', () {
    testWidgets(
      'Renderiza AppBar con botón Guardar Cambios y TabBar cápsula con 5 pestañas',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(_createConfiguracionScreen());
        await tester.pumpAndSettle();

        // AppBar y botón maestro
        expect(find.text('Centro de Control & Configuración'), findsOneWidget);
        expect(find.byKey(const Key('btnGuardarMaster')), findsOneWidget);

        // 5 Pestañas cápsula
        expect(find.text('1. Mi Tienda & Identidad'), findsOneWidget);
        expect(find.text('2. Equipo & Seguridad'), findsOneWidget);
        expect(find.text('3. Hardware & Tickets'), findsOneWidget);
        expect(find.text('4. Canales & Tienda Web'), findsOneWidget);
        expect(find.text('5. Plan & Facturación'), findsOneWidget);

        // Campos de pestaña 1
        expect(find.text('Perfil Comercial & SUNAT'), findsOneWidget);
        expect(find.text('Bodega San Martín'), findsWidgets);
      },
    );

    testWidgets(
      'Pestaña 1: Permite seleccionar color primario dinámico de tienda',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(_createConfiguracionScreen());
        await tester.pumpAndSettle();

        // Swatch Esmeralda Boutique (#0D9488)
        final swatchEsmeralda = find.byKey(const Key('swatch_#0D9488'));
        expect(swatchEsmeralda, findsOneWidget);

        await tester.tap(swatchEsmeralda);
        await tester.pumpAndSettle();

        // Guardar cambios y verificar SnackBar
        await tester.tap(find.byKey(const Key('btnGuardarMaster')));
        await tester.pumpAndSettle();

        expect(
          find.text('¡Configuración y privilegios guardados correctamente!'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Pestaña 2: Muestra colaboradores y gestiona presets de seguridad de cajero',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          _createConfiguracionScreen(tabInicial: ConfiguracionTab.usuarios),
        );
        await tester.pumpAndSettle();

        // Usuarios mock renderizados
        expect(find.text('Santiago Morales'), findsOneWidget);
        expect(find.text('Karla Cueva'), findsOneWidget);
        expect(find.text('ADMIN'), findsOneWidget);
        expect(find.text('CAJERO'), findsOneWidget);

        // Presets de seguridad
        expect(find.text('Cajero Estricto (Nuevo)'), findsOneWidget);
        expect(find.text('Cajero Regular'), findsOneWidget);
        expect(find.text('Encargado de Confianza'), findsOneWidget);

        // Tocar preset "Cajero Estricto (Nuevo)"
        await tester.tap(find.text('Cajero Estricto (Nuevo)'));
        await tester.pumpAndSettle();

        final switchDescuentos = tester.widget<Switch>(
          find.byKey(const Key('permDescuentos')),
        );
        expect(switchDescuentos.value, isFalse);

        // Tocar preset "Encargado de Confianza"
        await tester.tap(find.text('Encargado de Confianza'));
        await tester.pumpAndSettle();

        final switchCostosConfianza = tester.widget<Switch>(
          find.byKey(const Key('permCostos')),
        );
        final switchDescuentosConfianza = tester.widget<Switch>(
          find.byKey(const Key('permDescuentos')),
        );
        expect(switchCostosConfianza.value, isTrue);
        expect(switchDescuentosConfianza.value, isTrue);
      },
    );

    testWidgets(
      'Pestaña 2: Diálogo Nuevo Colaborador genera PIN de 4 dígitos aleatorio',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          _createConfiguracionScreen(tabInicial: ConfiguracionTab.usuarios),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btnNuevoCajero')));
        await tester.pumpAndSettle();

        expect(find.text('Nuevo Colaborador'), findsOneWidget);
        expect(find.byKey(const Key('btnGenerarPinAzar')), findsOneWidget);

        // Generar PIN al azar
        await tester.tap(find.byKey(const Key('btnGenerarPinAzar')));
        await tester.pumpAndSettle();

        final pinInput = tester.widget<TextField>(
          find.byKey(const Key('inputPinCajero')),
        );
        expect(pinInput.controller?.text.length, 4);

        // Ingresar nombre y usuario
        await tester.enterText(
          find.byKey(const Key('inputNombreCajero')),
          'Luis Paredes',
        );
        await tester.enterText(
          find.byKey(const Key('inputUsuarioCajero')),
          'luis',
        );
        await tester.pumpAndSettle();

        // Confirmar creación
        await tester.tap(find.byKey(const Key('btnConfirmarCrearCajero')));
        await tester.pumpAndSettle();

        expect(
          find.text('¡Colaborador luis creado exitosamente!'),
          findsOneWidget,
        );
        expect(find.text('Luis Paredes'), findsOneWidget);
      },
    );

    testWidgets(
      'Pestaña 3: Permite alternar ancho de papel 58mm y 80mm en ticket simulador lateral',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          _createConfiguracionScreen(tabInicial: ConfiguracionTab.hardware),
        );
        await tester.pumpAndSettle();

        expect(find.text('58 mm (Estándar)'), findsOneWidget);
        expect(find.text('80 mm (Mostrador Ancho)'), findsOneWidget);

        // Simulador de hardware en vivo con cabezal y pastilla de columnas
        expect(find.text('CAJAYA THERMAL POS'), findsOneWidget);
        expect(find.text('Papel 58 mm • 32 columnas ESC/POS'), findsOneWidget);
        expect(find.text('TICKET POS  B001-00293'), findsOneWidget);

        // Cambiar a 80mm
        await tester.tap(find.byKey(const Key('btnPapel80')));
        await tester.pumpAndSettle();

        // Pastilla actualizada a 80mm
        expect(find.text('Papel 80 mm • 48 columnas ESC/POS'), findsOneWidget);

        // Alternar switch de QR en ticket
        final qrSwitch = find.byKey(const Key('checkQrTicket'));
        expect(qrSwitch, findsOneWidget);
        await tester.tap(qrSwitch);
        await tester.pumpAndSettle();

        // Botón de imprimir ticket de prueba
        final btnPrint = find.byKey(const Key('btnImprimirTicketPrueba'));
        expect(btnPrint, findsOneWidget);
        await tester.ensureVisible(btnPrint);
        await tester.tap(btnPrint);
        await tester.pumpAndSettle();

        // Botón de probar apertura de gaveta
        final btnDrawer = find.byKey(const Key('btnProbarGaveta'));
        expect(btnDrawer, findsOneWidget);
        await tester.ensureVisible(btnDrawer);
        await tester.tap(btnDrawer);
        await tester.pumpAndSettle();
      },
    );
  });
}
