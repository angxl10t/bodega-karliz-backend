import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bodega_mobile/features/clientes/clientes_screen.dart';
import 'package:bodega_mobile/features/clientes/cliente_model.dart';
import 'package:bodega_mobile/features/clientes/cliente_service.dart';
import 'package:bodega_mobile/features/clientes/garantia_botella_model.dart';
import 'package:bodega_mobile/features/clientes/garantia_botella_service.dart';
import 'package:bodega_mobile/features/home/bodega_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final mockBodega = BodegaInfo(
    idBodega: 10,
    nombreComercial: 'Bodega Karliz',
    plan: 'PRO',
    colorPrimario: '#2563EB',
    estado: true,
    regimenTributario: 'RUS',
    esNuevoRus: true,
    facturacionSunatActiva: false,
    catalogoAbierto: true,
    telefono: '987654321',
  );

  final mockClientes = [
    Cliente(
      idCliente: 1,
      idBodega: 10,
      documento: '10458923',
      nombreCompleto: 'Rosa Alvarado Morales',
      telefono: '987654321',
      limiteCredito: 200.0,
      saldoDeudor: 120.0,
      creditoDisponible: 80.0,
      notas: 'Vecina CASERITO de la esquina, paga cada quincena',
    ),
    Cliente(
      idCliente: 2,
      idBodega: 10,
      documento: '09384756',
      nombreCompleto: 'Carlos Gutiérrez Ramos',
      telefono: '912345678',
      limiteCredito: 200.0,
      saldoDeudor: 190.0,
      creditoDisponible: 10.0,
      notas: 'Pendiente de pago desde hace 15 días',
    ),
    Cliente(
      idCliente: 3,
      idBodega: 10,
      documento: '44556677',
      nombreCompleto: 'María Elena Quispe',
      telefono: '955123456',
      limiteCredito: 300.0,
      saldoDeudor: 0.0,
      creditoDisponible: 300.0,
      notas: 'Excelente vecina CASERITO, siempre puntual',
    ),
  ];

  final mockResumenCreditos = ResumenCreditos(
    totalClientes: 3,
    clientesConDeuda: 2,
    totalSaldoDeudor: 310.0,
    totalAbonosMes: 850.0,
  );

  final mockGarantias = [
    GarantiaBotella(
      idGarantia: 1,
      idBodega: 10,
      idCliente: 1,
      nombrePersona: 'Miguel Ángel Soto',
      telefono: '981223344',
      cantidadBotellas: 4,
      montoGarantia: 12.0,
      tipoBotella: 'Cerveza Pilsen 650ml',
      estado: 'PENDIENTE',
      botellasDevueltas: 0,
      montoDevuelto: 0.0,
      botellasRestantes: 4,
      montoRestante: 12.0,
      fechaRegistro: DateTime.now(),
    ),
    GarantiaBotella(
      idGarantia: 2,
      idBodega: 10,
      idCliente: 3,
      nombrePersona: 'Ana Lucía Benítez',
      telefono: '976543210',
      cantidadBotellas: 2,
      montoGarantia: 6.0,
      tipoBotella: 'Coca Cola 1.5L Vidrio',
      estado: 'DEVUELTO',
      botellasDevueltas: 2,
      montoDevuelto: 6.0,
      botellasRestantes: 0,
      montoRestante: 0.0,
      fechaRegistro: DateTime.now().subtract(const Duration(days: 3)),
      fechaDevolucion: DateTime.now(),
    ),
  ];

  final mockResumenGarantias = ResumenGarantias(
    totalDineroCustodia: 12.0,
    botellasPendientes: 4,
    personasPendientes: 1,
    totalDevueltoMes: 24.0,
    botellasDevueltasMes: 8,
  );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({
      'jwt_token': 'fake_jwt_token',
      'user_rol': 'ADMIN',
      'plan_bodega': 'PRO',
      'nombre_bodega': 'Bodega Karliz',
    });
    SharedPreferences.setMockInitialValues({
      'user_rol': 'ADMIN',
      'plan_bodega': 'PRO',
    });
    ClienteService.setMockClientes(mockClientes, resumen: mockResumenCreditos);
    GarantiaBotellaService.setMockGarantias(
      mockGarantias,
      resumen: mockResumenGarantias,
    );
    BodegaService.setMockMiBodega(mockBodega);
  });

  tearDown(() {
    ClienteService.invalidateCache();
    GarantiaBotellaService.invalidateCache();
    BodegaService.clearCache();
  });

  group('ClientesScreen Calma Visual & Responsive Tests', () {
    testWidgets(
      'Desktop view (1280x800) renders cockpit, filter pills, and client cards without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ClientesScreen())),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Header title
        expect(find.text('Libreta de Fiados'), findsWidgets);
        expect(find.text('3 vecinos'), findsOneWidget);

        // Cockpit KPIs
        expect(find.text('Por Cobrar'), findsOneWidget);
        expect(find.text('S/ 310.00'), findsOneWidget);
        expect(find.text('Cobrado Mes'), findsOneWidget);
        expect(find.text('S/ 850.00'), findsOneWidget);
        expect(find.text('Vecinos al Día'), findsOneWidget);
        expect(find.text('Crédito Total'), findsOneWidget);

        // Filter chips
        expect(find.text('Todos (3)'), findsOneWidget);
        expect(find.text('Con Deuda (2)'), findsOneWidget);
        expect(find.text('Al Día (1)'), findsOneWidget);
        expect(find.text('Caseritos (2)'), findsOneWidget);

        // Client cards
        expect(find.text('Rosa Alvarado Morales'), findsOneWidget);
        expect(find.text('Carlos Gutiérrez Ramos'), findsOneWidget);
        expect(find.text('María Elena Quispe'), findsOneWidget);

        // Verification of no layout overflow
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Mobile view (390x844) renders without overflow and shows ergonomic actions',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ClientesScreen())),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Floating action button rendered on mobile
        expect(find.text('Nuevo Vecino'), findsOneWidget);

        // First customer card
        expect(find.text('Rosa Alvarado Morales'), findsOneWidget);
        expect(find.text('Cobrar / Abonar'), findsWidgets);
        expect(find.text('WhatsApp'), findsWidgets);

        // Verification of zero layout overflow
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Filter pill "Con Deuda" shows only debtors', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ClientesScreen())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on "Con Deuda (2)"
      await tester.tap(find.text('Con Deuda (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Rosa Alvarado Morales'), findsOneWidget);
      expect(find.text('Carlos Gutiérrez Ramos'), findsOneWidget);
      expect(find.text('María Elena Quispe'), findsNothing);
    });

    testWidgets('Filter pill "Al Día" shows only customers with zero debt', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ClientesScreen())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on "Al Día (1)"
      await tester.tap(find.text('Al Día (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Rosa Alvarado Morales'), findsNothing);
      expect(find.text('Carlos Gutiérrez Ramos'), findsNothing);
      expect(find.text('María Elena Quispe'), findsOneWidget);
    });

    testWidgets('Filter pill "Caseritos" shows only Caserito VIP customers', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ClientesScreen())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on "Caseritos (2)"
      await tester.tap(find.text('Caseritos (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Rosa Alvarado Morales'), findsOneWidget);
      expect(find.text('María Elena Quispe'), findsOneWidget);
      expect(find.text('Carlos Gutiérrez Ramos'), findsNothing);
    });

    testWidgets(
      'Tab switching to "Garantía de Botellas" renders bottle custody cockpit and records',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ClientesScreen())),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap on Tab 1
        await tester.tap(find.text('Garantía Botellas (4)'));
        await tester.pumpAndSettle();

        // Check bottle cockpit
        expect(find.text('Dinero en Custodia'), findsOneWidget);
        expect(find.text('S/ 12.00'), findsNWidgets(2));
        expect(find.text('Botellas Fuera'), findsOneWidget);
        expect(find.text('4 botellas'), findsOneWidget);

        // Check bottle record card
        expect(find.text('Miguel Ángel Soto'), findsOneWidget);
        expect(find.text('4 botellas • Cerveza Pilsen 650ml'), findsOneWidget);
        expect(
          find.text('Devolver Botella(s) y Entregar S/ 12.00'),
          findsOneWidget,
        );

        expect(tester.takeException(), isNull);
      },
    );
  });
}
