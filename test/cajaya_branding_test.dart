import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/core/theme.dart';
import 'package:bodega_mobile/core/theme_provider.dart';
import 'package:bodega_mobile/core/cajaya_vectors.dart';
import 'package:bodega_mobile/core/thermal_ticket_service.dart';
import 'package:bodega_mobile/features/home/bodega_service.dart';
import 'package:bodega_mobile/features/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('CajaYa Rebranding & Theming Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Option A palette constants are configured correctly', () {
      expect(AppTheme.brandPrimary, const Color(0xFF2563EB)); // Electric Cobalt
      expect(AppTheme.brandDark, const Color(0xFF1D4ED8));
      expect(AppTheme.brandLight, const Color(0xFF60A5FA));
      expect(AppTheme.brandInk, const Color(0xFF0B0F19)); // Obsidian Dark
      expect(AppTheme.bgDark, const Color(0xFF18181B)); // Warm Titanium Zinc 900
      expect(AppTheme.cardDark, const Color(0xFF27272A)); // Warm Titanium Zinc 800
      expect(AppTheme.cardDarkElevated, const Color(0xFF323238)); // Warm Titanium Zinc 750
    });

    test('ThemeProvider initializes with default Cobalt and updates dynamically', () async {
      final provider = ThemeProvider();
      expect(provider.accentColor, const Color(0xFF2563EB));

      // Level 2: Dynamically switch to Emerald
      await provider.setAccentColor(const Color(0xFF0D9488), hexCode: '#0D9488');
      expect(provider.accentColor, const Color(0xFF0D9488));
      expect(provider.lightTheme.colorScheme.primary, const Color(0xFF0D9488));
      expect(provider.darkTheme.colorScheme.primary, const Color(0xFF0D9488));
    });

    test('BodegaInfo deserializes JSON properly with Level 1 & 2 attributes', () {
      final json = {
        'idBodega': 2,
        'nombreComercial': 'Minimarket Los Laureles',
        'rucDni': '20123456789',
        'direccion': 'Av. Principal 456',
        'telefono': '999888777',
        'colorPrimario': '#4F46E5',
        'lemaComercial': 'Siempre frescos, siempre contigo',
        'plan': 'PRO',
        'estado': true,
      };

      final info = BodegaInfo.fromJson(json);
      expect(info.idBodega, 2);
      expect(info.nombreComercial, 'Minimarket Los Laureles');
      expect(info.rucDni, '20123456789');
      expect(info.colorPrimario, '#4F46E5');
      expect(info.lemaComercial, 'Siempre frescos, siempre contigo');
      expect(info.plan, 'PRO');
    });

    test('ThermalTicketService includes commercial slogan and tax ID in ticket header', () {
      final receipt = ThermalTicketService.generateReceiptText(
        ticketId: 105,
        clienteNombre: 'Maria Perez',
        clienteDocumento: '77665544',
        metodoPago: 'Yape',
        items: [
          TicketItem(nombre: 'Coca Cola 1.5L', cantidad: 2, precioUnitario: 7.50, subtotal: 15.00),
        ],
        total: 15.00,
        nombreComercio: 'BODEGA LOS ANDES',
        rucDni: '20601234567',
        direccion: 'Calle Los Pinos 102',
        telefono: '987111222',
        lemaComercial: 'Calidad y confianza en tu mesa',
      );

      expect(receipt.contains('BODEGA LOS ANDES'), isTrue);
      expect(receipt.contains('"Calidad y confianza en tu mesa"'), isTrue);
      expect(receipt.contains('RUC/DNI: 20601234567'), isTrue);
      expect(receipt.contains('CajaYa Cloud POS'), isTrue);
    });

    test('ThermalTicketService default ESC/POS uses CajaYa POS', () {
      final bytes = ThermalTicketService.generateEscPosBytes(
        ticketId: 1,
        clienteNombre: 'Cliente General',
        clienteDocumento: null,
        metodoPago: 'Efectivo',
        items: [
          TicketItem(nombre: 'Item Test', cantidad: 1, precioUnitario: 5.0, subtotal: 5.0),
        ],
        total: 5.0,
      );

      final textDecoded = String.fromCharCodes(bytes);
      expect(textDecoded.contains('CajaYa POS'), isTrue);
    });

    test('ThermalTicketService ESC/POS includes custom store metadata and sanitizes umlaut ü', () {
      final bytes = ThermalTicketService.generateEscPosBytes(
        ticketId: 2,
        clienteNombre: 'Güero Pérez',
        clienteDocumento: '12345678',
        metodoPago: 'Efectivo',
        items: [
          TicketItem(nombre: 'Agüita Mineral', cantidad: 1, precioUnitario: 2.50, subtotal: 2.50),
        ],
        total: 2.50,
        nombreComercio: 'Bodega La Cigüeña',
        rucDni: '10443322119',
        lemaComercial: 'Calidad y confianza',
        direccion: 'Av. Las Flores 789',
        telefono: '999111333',
      );

      final textDecoded = String.fromCharCodes(bytes);
      expect(textDecoded.contains('Bodega La Ciguena'), isTrue);
      expect(textDecoded.contains('Aguita Mineral'), isTrue);
      expect(textDecoded.contains('Guero Perez'), isTrue);
      expect(textDecoded.contains('RUC/DNI: 10443322119'), isTrue);
      expect(textDecoded.contains('"Calidad y confianza"'), isTrue);
    });
  });

  group('CajaYa Vector Widgets Tests', () {
    testWidgets('CajaYaLogoMark renders without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CajaYaLogoMark(size: 44),
            ),
          ),
        ),
      );

      expect(find.byType(CajaYaLogoMark), findsOneWidget);
    });

    testWidgets('CajaYaHeroGraphic renders without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CajaYaHeroGraphic(width: 320, height: 160),
            ),
          ),
        ),
      );

      expect(find.byType(CajaYaHeroGraphic), findsOneWidget);
      expect(find.text('POS ONLINE'), findsOneWidget);
      expect(find.text('Venta Rápida'), findsOneWidget);
    });

    testWidgets('LoginScreen renders compact mobile view on small screens', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bienvenido a tu Punto de Venta'), findsOneWidget);
      expect(find.text('INGRESAR AL SISTEMA'), findsOneWidget);
      expect(find.text('Registra tu bodega gratis'), findsOneWidget);
    });

    testWidgets('LoginScreen renders split-screen brand showcase on desktop screens', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('El Punto de Venta más rápido para tu negocio'), findsOneWidget);
      expect(find.text('Ventas en < 3 segundos'), findsOneWidget);
      expect(find.text('Multi-cajero con control de roles'), findsOneWidget);
      expect(find.text('INGRESAR AL SISTEMA'), findsOneWidget);
    });
  });
}

