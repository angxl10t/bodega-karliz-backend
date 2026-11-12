import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:bodega_mobile/core/theme_provider.dart';
import 'package:bodega_mobile/features/home/bodega_service.dart';
import 'package:bodega_mobile/features/superadmin/superadmin_dashboard_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Superadmin Data Models & Serialization Tests', () {
    test('PagoSuscripcionItem parses Yape payment correctly', () {
      final json = {
        'idPago': 101,
        'idBodega': 5,
        'nombreBodega': 'Bodega Las Tres Marías',
        'plan': 'PRO',
        'monto': 29.90,
        'billetera': 'YAPE',
        'codigoOperacion': 'YP-884920',
        'fechaPago': '2026-10-20T10:30:00Z',
        'estado': 'CONFIRMADO',
      };

      final pago = PagoSuscripcionItem.fromJson(json);

      expect(pago.idPago, 101);
      expect(pago.idBodega, 5);
      expect(pago.nombreBodega, 'Bodega Las Tres Marías');
      expect(pago.plan, 'PRO');
      expect(pago.monto, 29.90);
      expect(pago.billetera, 'YAPE');
      expect(pago.codigoOperacion, 'YP-884920');
      expect(pago.estado, 'CONFIRMADO');
      expect(pago.fechaPago, isNotNull);
    });

    test('PagoSuscripcionItem parses Plin payment with null optional fields safely', () {
      final json = {
        'idPago': 102,
        'billetera': 'PLIN',
        'codigoOperacion': 'PL-110022',
        'monto': 15.00,
      };

      final pago = PagoSuscripcionItem.fromJson(json);

      expect(pago.idPago, 102);
      expect(pago.idBodega, isNull);
      expect(pago.nombreBodega, isNull);
      expect(pago.plan, 'PRO');
      expect(pago.monto, 15.00);
      expect(pago.billetera, 'PLIN');
      expect(pago.codigoOperacion, 'PL-110022');
      expect(pago.estado, 'CONFIRMADO');
      expect(pago.fechaPago, isNull);
    });

    test('BodegaInfo includes tenant activation state and validity date', () {
      final json = {
        'idBodega': 8,
        'nombreComercial': 'Minimarket Don Pepe',
        'rucDni': '10458920112',
        'plan': 'PRO',
        'estado': true,
        'fechaVencimientoPlan': '2026-12-31T23:59:59Z',
      };

      final bodega = BodegaInfo.fromJson(json);

      expect(bodega.idBodega, 8);
      expect(bodega.nombreComercial, 'Minimarket Don Pepe');
      expect(bodega.estado, isTrue);
      expect(bodega.plan, 'PRO');
      expect(bodega.fechaVencimientoPlan, '2026-12-31T23:59:59Z');
    });

    test('BodegaInfo calculates plan expiration days correctly', () {
      final futureDate = DateTime.now()
          .add(const Duration(days: 15))
          .toIso8601String();
      final json = {
        'idBodega': 9,
        'nombreComercial': 'Bodega Esperanza',
        'plan': 'BASICO',
        'estado': true,
        'fechaVencimientoPlan': futureDate,
      };

      final bodega = BodegaInfo.fromJson(json);
      final exp = DateTime.parse(bodega.fechaVencimientoPlan!);
      final diff = exp.difference(DateTime.now()).inDays;

      expect(diff, inInclusiveRange(14, 15));
    });

    test('StarterPackPresetItem serializes and deserializes JSON correctly', () {
      final json = {
        'idPreset': 1,
        'codigoBarras': '7750106001015',
        'nombre': 'Arroz Costeño Extra 1kg',
        'marca': 'Costeño',
        'categoria': 'ABARROTES',
        'precioVenta': 4.80,
        'precioCosto': 3.90,
        'imagenUrl': 'https://res.cloudinary.com/cajaya/arroz.jpg',
        'activo': true,
      };

      final item = StarterPackPresetItem.fromJson(json);

      expect(item.idPreset, 1);
      expect(item.codigoBarras, '7750106001015');
      expect(item.nombre, 'Arroz Costeño Extra 1kg');
      expect(item.marca, 'Costeño');
      expect(item.categoria, 'ABARROTES');
      expect(item.precioVenta, 4.80);
      expect(item.precioCosto, 3.90);
      expect(item.imagenUrl, 'https://res.cloudinary.com/cajaya/arroz.jpg');
      expect(item.activo, isTrue);

      final outJson = item.toJson();
      expect(outJson['codigoBarras'], '7750106001015');
      expect(outJson['precioVenta'], 4.80);
      expect(outJson['activo'], isTrue);
    });

    test('StarterPackPresetItem parses nullables and numeric strings gracefully', () {
      final json = {
        'idPreset': '42',
        'codigoBarras': '7750106009999',
        'nombre': 'Gaseosa Inca Kola 500ml',
        'categoria': 'BEBIDAS',
        'precioVenta': '3.50',
        'precioCosto': '2.80',
        'activo': false,
      };

      final item = StarterPackPresetItem.fromJson(json);

      expect(item.idPreset, 42);
      expect(item.codigoBarras, '7750106009999');
      expect(item.marca, isNull);
      expect(item.imagenUrl, isNull);
      expect(item.precioVenta, 3.50);
      expect(item.precioCosto, 2.80);
      expect(item.activo, isFalse);
    });
  });

  group('Superadmin Console Widget & Navigation Tests', () {
    testWidgets('SuperAdminDashboardScreen renders loading state initially', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          child: const MaterialApp(home: SuperAdminDashboardScreen()),
        ),
      );

      // Verify header branding and Superadmin Root badge
      expect(find.text('CajaYa'), findsWidgets);
      expect(find.text('SUPERADMIN ROOT'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });
}
