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
      final futureDate = DateTime.now().add(const Duration(days: 15)).toIso8601String();
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
  });

  group('Superadmin Console Widget & Navigation Tests', () {
    testWidgets('SuperAdminDashboardScreen renders loading state initially', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          child: const MaterialApp(
            home: SuperAdminDashboardScreen(),
          ),
        ),
      );

      // Verify header branding and Superadmin Root badge
      expect(find.text('CajaYa'), findsWidgets);
      expect(find.text('SUPERADMIN ROOT'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });
}
