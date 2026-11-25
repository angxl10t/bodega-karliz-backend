import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bodega_mobile/core/offline/offline_sync_manager.dart';
import 'package:bodega_mobile/core/theme.dart';
import 'package:bodega_mobile/features/clientes/cliente_model.dart';
import 'package:bodega_mobile/features/clientes/cliente_service.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/ventas/venta_model.dart';
import 'package:bodega_mobile/features/ventas/venta_service.dart';
import 'package:bodega_mobile/features/ventas/widgets/mostrador_calculadora_view.dart';

class _FakeVentaService extends VentaService {
  RegistroVentaResult nextResult;
  final List<VentaEnvio> sentVentas = [];

  _FakeVentaService({RegistroVentaResult? initialResult})
    : nextResult = initialResult ?? RegistroVentaResult(success: true);

  @override
  Future<CierreCaja?> getCierreCajaHoy() async => null;

  @override
  Future<RegistroVentaResult> registrarVentaCompleta(VentaEnvio venta) async {
    sentVentas.add(venta);
    return nextResult;
  }
}

class _FakeClienteService extends ClienteService {
  final List<Cliente> clientes;
  final bool shouldThrow;
  Cliente? lastCreated;

  _FakeClienteService({this.clientes = const [], this.shouldThrow = false});

  @override
  Future<List<Cliente>> getClientes({
    String? query,
    bool soloDeudores = false,
    bool forceRefresh = false,
  }) async {
    if (shouldThrow) {
      throw Exception('Sin conexión al servidor de vecinos');
    }
    return clientes;
  }

  @override
  Future<Cliente> crearCliente(Map<String, dynamic> data) async {
    final nuevo = Cliente(
      idCliente: (clientes.length + 1) * 100,
      nombreCompleto: data['nombreCompleto'] ?? 'Nuevo Vecino',
      telefono: data['telefono'],
      limiteCredito: (data['limiteCredito'] as num?)?.toDouble() ?? 200.0,
      saldoDeudor: 0.0,
    );
    lastCreated = nuevo;
    return nuevo;
  }
}

Widget _createMostradorApp({
  Key? appKey,
  required List<Producto> productos,
  required VoidCallback onVolverAPos,
  bool isDark = false,
  VentaService? ventaService,
  ClienteService? clienteService,
}) {
  return MaterialApp(
    key: appKey,
    theme: isDark ? AppTheme.buildDarkTheme() : AppTheme.buildLightTheme(),
    home: Scaffold(
      body: MostradorCalculadoraView(
        productosDisponibles: productos,
        onVolverAPos: onVolverAPos,
        isDark: isDark,
        ventaService: ventaService,
        clienteService: clienteService,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<Producto> dummyProductos = [
    Producto(
      idProducto: 1,
      codigo: 'PROD-001',
      nombre: 'Leche Gloria Azul 400g',
      precioVenta: 4.50,
      precioCosto: 3.80,
      stockActual: 24,
      nombreCategoria: 'Lácteos',
      codigoBarras: '7750123456789',
    ),
    Producto(
      idProducto: 2,
      codigo: 'PROD-002',
      nombre: 'Arroz Costeño 1kg',
      precioVenta: 5.20,
      precioCosto: 4.40,
      stockActual: 50,
      nombreCategoria: 'Abarrotes',
      codigoBarras: '7750987654321',
    ),
  ];

  setUp(() {
    OfflineSyncManager.instance.isOfflineNotifier.value = false;
    FlutterSecureStorage.setMockInitialValues({
      'jwt_token': 'fake_token',
      'id_bodega': '1',
    });
    SharedPreferences.setMockInitialValues({
      'cajaya_mostrador_subvista_activa': 'calculadora',
    });
  });

  testWidgets(
    'MostradorCalculadoraView inicializa en vista calculadora y suma montos al ticket',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool volvioAPos = false;

      await tester.pumpWidget(
        _createMostradorApp(
          productos: dummyProductos,
          onVolverAPos: () => volvioAPos = true,
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar conmutador segmentado en barra superior
      expect(find.text('Calculadora'), findsOneWidget);
      expect(find.text('Catálogo'), findsOneWidget);

      // Ingresar '4', '.', '5', '0' en el teclado numérico usando sus keys
      await tester.tap(find.byKey(const ValueKey('numpad_4')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('numpad_.')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('numpad_5')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('numpad_0')));
      await tester.pump();

      // Presionar botón SUMAR AL TICKET
      final btnSumar = find.text('SUMAR AL\nTICKET');
      expect(btnSumar, findsOneWidget);
      await tester.tap(btnSumar);
      await tester.pump();

      // El ticket ahora debe listar la primera línea con S/ 4.50
      expect(find.text('S/ 4.50'), findsOneWidget);
      expect(find.text('4.50'), findsOneWidget);

      // Ingresar segundo producto: '2' (S/ 2.00)
      await tester.tap(find.byKey(const ValueKey('numpad_2')));
      await tester.pump();
      await tester.tap(btnSumar);
      await tester.pump();

      // El total ahora debe ser 4.50 + 2.00 = 6.50
      expect(find.text('S/ 2.00'), findsOneWidget);
      expect(find.text('6.50'), findsOneWidget);

      // Probar Deshacer último
      final btnDeshacer = find.text('Deshacer último');
      expect(btnDeshacer, findsOneWidget);
      await tester.tap(btnDeshacer);
      await tester.pump();

      // El total debe volver a S/ 4.50
      expect(find.text('4.50'), findsOneWidget);

      // Probar volver a POS mediante el botón en barra superior
      final btnVolver = find.byTooltip('Volver al POS tradicional');
      expect(btnVolver, findsOneWidget);
      await tester.tap(btnVolver);
      await tester.pump();
      expect(volvioAPos, isTrue);
    },
  );

  testWidgets(
    'Permite alternar entre Calculadora de Mostrador y Catálogo & Buscador',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _createMostradorApp(productos: dummyProductos, onVolverAPos: () {}),
      );
      await tester.pumpAndSettle();

      // Inicialmente en calculadora
      expect(find.text('SUMAR AL\nTICKET'), findsOneWidget);

      // Alternar a Catálogo
      final btnTabCatalogo = find.text('Catálogo');
      await tester.tap(btnTabCatalogo);
      await tester.pumpAndSettle();

      // Ahora debe mostrar el buscador y los productos
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Leche Gloria Azul 400g'), findsOneWidget);
      expect(find.text('Arroz Costeño 1kg'), findsOneWidget);

      // Alternar de vuelta a Calculadora
      final btnTabCalculadora = find.text('Calculadora');
      await tester.tap(btnTabCalculadora);
      await tester.pumpAndSettle();

      // Vuelve a mostrar el teclado numérico
      expect(find.text('SUMAR AL\nTICKET'), findsOneWidget);
    },
  );

  testWidgets('Cálculo de vuelto con billetes rápidos en efectivo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      _createMostradorApp(productos: dummyProductos, onVolverAPos: () {}),
    );
    await tester.pumpAndSettle();

    // Cargar un monto de S/ 15.00
    await tester.tap(find.byKey(const ValueKey('numpad_1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('numpad_5')));
    await tester.pump();
    await tester.tap(find.text('SUMAR AL\nTICKET'));
    await tester.pump();

    // Abrir selector de billetes en Efectivo
    final btnEfectivo = find.text('EFECTIVO');
    expect(btnEfectivo, findsOneWidget);
    await tester.tap(btnEfectivo);
    await tester.pumpAndSettle();

    // Deben aparecer los chips de billetes (Exacto, S/ 20, S/ 50, S/ 100)
    expect(find.text('Exacto'), findsOneWidget);
    expect(find.text('S/ 20'), findsOneWidget);

    // Tocar billete S/ 20
    await tester.tap(find.text('S/ 20'));
    await tester.pumpAndSettle();

    // Debe calcular y mostrar el vuelto exacto: S/ 20 - S/ 15 = S/ 5.00
    expect(find.textContaining('VUELTO A ENTREGAR'), findsOneWidget);
    expect(find.textContaining('5.00'), findsWidgets);
  });

  testWidgets(
    'Combina productos del catálogo + 1.50 de Pan en una sola venta unificada',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeVenta = _FakeVentaService();
      final fakeClientes = _FakeClienteService();
      OfflineSyncManager.instance.isOfflineNotifier.value = false;

      await tester.pumpWidget(
        _createMostradorApp(
          productos: dummyProductos,
          onVolverAPos: () {},
          ventaService: fakeVenta,
          clienteService: fakeClientes,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Cambiar a Catálogo y seleccionar Leche Gloria (S/ 4.50)
      await tester.tap(find.text('Catálogo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leche Gloria Azul 400g'));
      await tester.pumpAndSettle();
      expect(find.text('×1'), findsOneWidget);

      // 2. Volver a Calculadora y sumar S/ 1.50 etiquetado como "Pan" en la MISMA cuenta
      await tester.tap(find.text('Calculadora'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pan'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('numpad_1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('numpad_.')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('numpad_5')));
      await tester.pump();
      await tester.tap(find.text('SUMAR AL\nTICKET'));
      await tester.pump();

      // La tira de cuenta contiene ambos ítems juntos y el total unificado es S/ 6.00
      expect(find.text('Leche Gloria Azul 400g'), findsOneWidget);
      expect(find.text('Pan'), findsWidgets);
      expect(find.text('6.00'), findsOneWidget);

      // 3. Cobrar toda la cuenta junta con YAPE / PLIN
      await tester.tap(find.text('YAPE / PLIN'));
      await tester.pumpAndSettle();

      // Solo se envía el ítem real de catálogo (no corrompe otro producto con el monto manual)
      expect(fakeVenta.sentVentas.length, 1);
      expect(fakeVenta.sentVentas.first.detalles.length, 1);
      expect(fakeVenta.sentVentas.first.detalles.first.idProducto, 1);
      expect(fakeVenta.sentVentas.first.metodoPago, 'Yape');
      expect(find.textContaining('Cobrado S/ 6.00'), findsOneWidget);
    },
  );

  testWidgets(
    'Deshacer multi-paso revierte +1 accidental sin borrar toda la línea y backspace borra dígito',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _createMostradorApp(
          productos: dummyProductos,
          onVolverAPos: () {},
          ventaService: _FakeVentaService(),
          clienteService: _FakeClienteService(),
        ),
      );
      await tester.pumpAndSettle();

      // Probar backspace: escribir 45, borrar 5 -> queda 4.00
      await tester.tap(find.byKey(const ValueKey('numpad_4')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('numpad_5')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('numpad_backspace')));
      await tester.pump();
      expect(find.text('S/ 4'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('numpad_C')));
      await tester.pump();

      // Agregar Leche Gloria dos veces seguidas en Catálogo (×2 = 9.00)
      await tester.tap(find.text('Catálogo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leche Gloria Azul 400g'));
      await tester.pump();
      await tester.tap(find.text('Leche Gloria Azul 400g'));
      await tester.pumpAndSettle();
      expect(find.text('×2'), findsOneWidget);
      expect(find.text('S/ 9.00'), findsOneWidget);

      // Deshacer último revierte de ×2 a ×1 (S/ 4.50) sin eliminar el producto
      await tester.tap(find.byTooltip('Deshacer último'));
      await tester.pumpAndSettle();
      expect(find.text('×1'), findsOneWidget);
      expect(find.text('1 items en cuenta'), findsOneWidget);
      expect(find.text('S/ 4.50'), findsWidgets);
    },
  );

  testWidgets(
    'Permite editar cantidad decimal 1.5 y filtrar categorías con tildes',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _createMostradorApp(
          productos: dummyProductos,
          onVolverAPos: () {},
          ventaService: _FakeVentaService(),
          clienteService: _FakeClienteService(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Catálogo'));
      await tester.pumpAndSettle();

      // Filtrar por categoría con tilde (Lácteos) debe mantener Leche Gloria y ocultar Arroz
      await tester.tap(find.text('🥛 Lácteos'));
      await tester.pumpAndSettle();
      expect(find.text('Leche Gloria Azul 400g'), findsOneWidget);
      expect(find.text('Arroz Costeño 1kg'), findsNothing);

      // Volver a Todos y agregar Arroz Costeño 1kg (S/ 5.20)
      await tester.tap(find.text('⭐ Todos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arroz Costeño 1kg'));
      await tester.pumpAndSettle();

      // Tocar badge ×1 para cambiar cantidad a 1.5 -> subtotal S/ 7.80
      await tester.tap(find.text('×1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, '1.5'));
      await tester.pump();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();

      expect(find.text('×1.5'), findsOneWidget);
      expect(find.text('S/ 7.80'), findsOneWidget);
    },
  );

  testWidgets(
    'Manejo de errores: monto vacío, sin stock, billete menor, exceso crédito y rechazo servidor',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final productosConAgotado = [
        ...dummyProductos,
        Producto(
          idProducto: 3,
          codigo: 'PROD-003',
          nombre: 'Aceite Agotado',
          precioVenta: 8.50,
          stockActual: 0,
          nombreCategoria: 'Abarrotes',
        ),
      ];

      final fakeVenta = _FakeVentaService(
        initialResult: RegistroVentaResult(
          success: false,
          errorMessage: 'Stock insuficiente en servidor',
        ),
      );
      final fakeClientes = _FakeClienteService(
        clientes: [
          Cliente(
            idCliente: 10,
            nombreCompleto: 'Juan Perez',
            limiteCredito: 10.0,
            saldoDeudor: 8.0,
          ),
        ],
      );
      OfflineSyncManager.instance.isOfflineNotifier.value = false;

      await tester.pumpWidget(
        _createMostradorApp(
          productos: productosConAgotado,
          onVolverAPos: () {},
          ventaService: fakeVenta,
          clienteService: fakeClientes,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Error al presionar SUMAR AL TICKET sin ingresar monto
      await tester.tap(find.text('SUMAR AL\nTICKET'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Digita un monto mayor a S/ 0.00'),
        findsOneWidget,
      );

      // 2. Producto sin stock en Catálogo no se agrega y muestra alerta
      await tester.tap(find.text('Catálogo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceite Agotado'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Sin stock disponible para Aceite Agotado'),
        findsOneWidget,
      );

      // Agregar Arroz Costeño (S/ 5.20) y Leche Gloria (S/ 4.50) x2 = S/ 14.20
      await tester.tap(find.text('Arroz Costeño 1kg'));
      await tester.pump();
      await tester.tap(find.text('Leche Gloria Azul 400g'));
      await tester.pump();
      await tester.tap(find.text('Leche Gloria Azul 400g'));
      await tester.pumpAndSettle();

      // 3. En Efectivo, elegir billete S/ 10 cuando total es S/ 14.20 muestra advertencia
      await tester.tap(find.text('EFECTIVO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('S/ 10'));
      await tester.pumpAndSettle();
      expect(find.textContaining('es menor al total'), findsOneWidget);

      // 4. En Fiado, vecino con límite excedido muestra error y NO limpia ticket
      await tester.tap(find.text('FIAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Juan Perez'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Límite de crédito excedido'), findsOneWidget);
      expect(find.text('S/ 14.20'), findsOneWidget);

      // 5. En Yape, si servidor rechaza la venta con error de negocio, NO limpia el ticket
      await tester.tap(find.text('YAPE / PLIN'));
      await tester.pumpAndSettle();
      expect(find.text('Stock insuficiente en servidor'), findsOneWidget);
      expect(find.text('S/ 14.20'), findsOneWidget);
    },
  );

  testWidgets(
    'Permite agregar monto rápido directo desde Catálogo, ver cuenta unificada y reintentar clientes',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeClientesError = _FakeClienteService(shouldThrow: true);

      await tester.pumpWidget(
        _createMostradorApp(
          productos: dummyProductos,
          onVolverAPos: () {},
          ventaService: _FakeVentaService(),
          clienteService: fakeClientesError,
        ),
      );
      await tester.pumpAndSettle();

      // Alternar a Catálogo y agregar Arroz (S/ 5.20)
      await tester.tap(find.text('Catálogo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arroz Costeño 1kg'));
      await tester.pumpAndSettle();

      // Abrir diálogo rápido "+ Monto" desde Catálogo para añadir S/ 1.50 de Pan
      await tester.tap(find.byKey(const ValueKey('btn_monto_rapido_catalogo')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Monto en S/ (ej: 1.50)'),
        '1.50',
      );
      await tester.tap(find.text('Sumar al ticket'));
      await tester.pumpAndSettle();

      // Cuenta unificada debe sumar 5.20 + 1.50 = S/ 6.70 y mostrar 2 items
      expect(find.text('2 items en cuenta'), findsOneWidget);
      expect(find.text('S/ 6.70'), findsOneWidget);

      // Abrir detalle de cuenta unificada ('Ver / editar')
      await tester.tap(find.text('Ver / editar'));
      await tester.pumpAndSettle();
      expect(find.text('CUENTA UNIFICADA (2 ítems)'), findsOneWidget);
      expect(find.text('Pan'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();

      // Abrir FIAR cuando falló la carga de vecinos debe mostrar error con botón Reintentar
      await tester.tap(find.text('FIAR'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudieron cargar los vecinos.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    },
  );

  testWidgets(
    'Vista vertical de tablet no genera overflow ni sobrepone TOTAL A COBRAR sobre la calculadora',
    (tester) async {
      for (final size in [
        const Size(600, 960),
        const Size(688, 1024),
        const Size(768, 1024),
        const Size(600, 500),
      ]) {
        SharedPreferences.setMockInitialValues({
          'cajaya_mostrador_subvista_activa': 'calculadora',
        });
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          _createMostradorApp(
            appKey: ValueKey(size),
            productos: dummyProductos,
            onVolverAPos: () {},
            ventaService: _FakeVentaService(),
            clienteService: _FakeClienteService(),
          ),
        );
        await tester.pumpAndSettle();

        // Verifica que TOTAL A COBRAR no se traslapa ni con la lista vacía ni con MONTO A SUMAR
        final totalRect = tester.getRect(find.text('TOTAL A COBRAR'));
        final numpadHeaderRect = tester.getRect(find.text('MONTO A SUMAR:'));
        expect(
          totalRect.overlaps(numpadHeaderRect),
          isFalse,
          reason: 'TOTAL A COBRAR se sobrepone sobre MONTO A SUMAR en $size',
        );
        if (size.width < 720) {
          expect(
            totalRect.bottom <= numpadHeaderRect.top,
            isTrue,
            reason:
                'TOTAL A COBRAR invade verticalmente a la calculadora en $size ($totalRect vs $numpadHeaderRect)',
          );
        }

        // Agrega monto 15 y verifica lista + EFECTIVO abierto sin overflow
        await tester.ensureVisible(find.byKey(const ValueKey('numpad_1')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('numpad_1')));
        await tester.pump();
        await tester.ensureVisible(find.byKey(const ValueKey('numpad_5')));
        await tester.tap(find.byKey(const ValueKey('numpad_5')));
        await tester.pump();
        final sumarBtn = find.text('SUMAR AL\nTICKET');
        await tester.ensureVisible(sumarBtn);
        await tester.tap(sumarBtn);
        await tester.pump();

        expect(find.text('S/ 15.00'), findsOneWidget);

        // Alternar a Catálogo con EFECTIVO abierto en vertical de tablet
        await tester.tap(find.text('Catálogo'));
        await tester.pumpAndSettle();
        final efectivoBtn = find.text('EFECTIVO');
        await tester.ensureVisible(efectivoBtn);
        await tester.tap(efectivoBtn);
        await tester.pumpAndSettle();
        expect(find.text('Exacto'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'Vista vertical de tablet con escala de texto 1.2x mantiene TOTAL A COBRAR sin overflow',
    (tester) async {
      for (final size in [const Size(600, 960), const Size(688, 1024)]) {
        SharedPreferences.setMockInitialValues({
          'cajaya_mostrador_subvista_activa': 'calculadora',
        });
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 1.2;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });

        await tester.pumpWidget(
          _createMostradorApp(
            appKey: ValueKey('scaled_$size'),
            productos: dummyProductos,
            onVolverAPos: () {},
            ventaService: _FakeVentaService(),
            clienteService: _FakeClienteService(),
          ),
        );
        await tester.pumpAndSettle();

        final totalRect = tester.getRect(find.text('TOTAL A COBRAR'));
        final numpadHeaderRect = tester.getRect(find.text('MONTO A SUMAR:'));
        expect(totalRect.overlaps(numpadHeaderRect), isFalse);
        expect(totalRect.bottom <= numpadHeaderRect.top, isTrue);
      }
    },
  );

  testWidgets(
    'Botón Deshacer último mantiene contraste legible (>= 4.5:1) en tema claro y oscuro, habilitado e inhabilitado',
    (tester) async {
      double contrastRatio(Color fg, Color bg) {
        final l1 = fg.computeLuminance();
        final l2 = bg.computeLuminance();
        return (l1 > l2 ? l1 + 0.05 : l2 + 0.05) /
            (l1 > l2 ? l2 + 0.05 : l1 + 0.05);
      }

      for (final isDark in [false, true]) {
        SharedPreferences.setMockInitialValues({
          'cajaya_mostrador_subvista_activa': 'calculadora',
        });
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _createMostradorApp(
            appKey: ValueKey('undo_contrast_$isDark'),
            isDark: isDark,
            productos: dummyProductos,
            onVolverAPos: () {},
            ventaService: _FakeVentaService(),
            clienteService: _FakeClienteService(),
          ),
        );
        await tester.pumpAndSettle();

        final btnFinder = find.ancestor(
          of: find.text('Deshacer último'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );
        expect(btnFinder, findsOneWidget);

        // Estado deshabilitado inicial
        final disabledBtn = tester.widget<ButtonStyleButton>(btnFinder);
        expect(disabledBtn.onPressed, isNull);
        final disabledFg = disabledBtn.style!.foregroundColor!.resolve({
          WidgetState.disabled,
        })!;
        final disabledBg = disabledBtn.style!.backgroundColor!.resolve({
          WidgetState.disabled,
        })!;
        expect(
          contrastRatio(disabledFg, disabledBg),
          greaterThanOrEqualTo(4.5),
          reason:
              'Contraste insuficiente deshabilitado (isDark=$isDark): $disabledFg sobre $disabledBg',
        );

        // Agrega S/ 5 y verifica estado habilitado
        await tester.tap(find.byKey(const ValueKey('numpad_5')));
        await tester.pump();
        await tester.tap(find.text('SUMAR AL\nTICKET'));
        await tester.pump();

        final enabledBtn = tester.widget<ButtonStyleButton>(btnFinder);
        expect(enabledBtn.onPressed, isNotNull);
        final enabledFg = enabledBtn.style!.foregroundColor!.resolve({})!;
        final enabledBg = enabledBtn.style!.backgroundColor!.resolve({})!;
        expect(
          contrastRatio(enabledFg, enabledBg),
          greaterThanOrEqualTo(4.5),
          reason:
              'Contraste insuficiente habilitado (isDark=$isDark): $enabledFg sobre $enabledBg',
        );
      }
    },
  );

  testWidgets(
    'Botón FIADO abre modal para seleccionar cliente existente o crear uno nuevo',
    (tester) async {
      final fakeVentaService = _FakeVentaService();
      final clienteExistente = Cliente(
        idCliente: 42,
        nombreCompleto: 'Don Carlos Mendoza',
        telefono: '987654321',
        limiteCredito: 100.0,
        saldoDeudor: 10.0,
      );
      final fakeClienteService = _FakeClienteService(
        clientes: [clienteExistente],
      );
      OfflineSyncManager.instance.isOfflineNotifier.value = false;

      await tester.pumpWidget(
        _createMostradorApp(
          productos: dummyProductos,
          onVolverAPos: () {},
          ventaService: fakeVentaService,
          clienteService: fakeClienteService,
        ),
      );
      await tester.pumpAndSettle();

      // Cambiar a Catálogo y seleccionar Leche Gloria (S/ 4.50)
      await tester.tap(find.text('Catálogo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leche Gloria Azul 400g'));
      await tester.pumpAndSettle();

      expect(find.text('S/ 4.50'), findsWidgets);

      // Tocar FIAR para abrir el modal
      await tester.tap(find.text('FIAR'));
      await tester.pumpAndSettle();

      // Verificar que el modal de fiado está abierto
      expect(find.text('Seleccionar vecino para fiado'), findsOneWidget);
      expect(find.text('Total a fiar: S/ 4.50'), findsOneWidget);
      expect(find.text('Don Carlos Mendoza'), findsOneWidget);
      expect(find.text('Disponible: S/ 90.00 • 987654321'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('btn_nuevo_cliente_fiado')),
        findsOneWidget,
      );

      // Probar filtro de búsqueda
      final searchField = find.widgetWithText(
        TextField,
        'Buscar vecino o celular...',
      );
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'noexiste');
      await tester.pumpAndSettle();
      expect(find.text('No se encontró a "noexiste"'), findsOneWidget);
      expect(find.text('Registrar como nuevo cliente'), findsOneWidget);

      // Limpiar búsqueda
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();
      expect(find.text('Don Carlos Mendoza'), findsOneWidget);

      // Seleccionar a Don Carlos Mendoza para completar la venta a crédito
      await tester.tap(find.text('Don Carlos Mendoza'));
      await tester.pumpAndSettle();

      // Verificar que la venta se registró con CREDITO y el cliente 42
      expect(fakeVentaService.sentVentas.length, 1);
      final envio = fakeVentaService.sentVentas.first;
      expect(envio.metodoPago, 'Crédito');
      expect(envio.idCliente, 42);
      expect(envio.clienteNombre, 'Don Carlos Mendoza');

      // El ticket debe haberse limpiado y muestra confirmación de cobrado
      expect(find.textContaining('Cobrado S/ 4.50 con Crédito'), findsOneWidget);
      expect(find.textContaining('items en cuenta'), findsNothing);
      expect(find.text('×1'), findsNothing);
    },
  );

  testWidgets(
    'Permite registrar un nuevo cliente desde el modal de fiado y completar la venta',
    (tester) async {
      final fakeVentaService = _FakeVentaService();
      final fakeClienteService = _FakeClienteService(clientes: []);
      OfflineSyncManager.instance.isOfflineNotifier.value = false;

      await tester.pumpWidget(
        _createMostradorApp(
          productos: dummyProductos,
          onVolverAPos: () {},
          ventaService: fakeVentaService,
          clienteService: fakeClienteService,
        ),
      );
      await tester.pumpAndSettle();

      // Cambiar a Catálogo y seleccionar Arroz Costeño (S/ 5.20)
      await tester.tap(find.text('Catálogo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arroz Costeño 1kg'));
      await tester.pumpAndSettle();

      // Tocar FIAR
      await tester.tap(find.text('FIAR'));
      await tester.pumpAndSettle();

      // Como no hay clientes registrados, muestra estado vacío y botón para nuevo cliente
      expect(find.text('No hay clientes registrados aún.'), findsOneWidget);
      expect(find.text('Registrar nuevo cliente'), findsOneWidget);

      // Tocar botón "+ Nuevo" en el modal
      await tester.tap(find.byKey(const ValueKey('btn_nuevo_cliente_fiado')));
      await tester.pumpAndSettle();

      // Se abre NuevoClienteSheet
      expect(find.text('Registrar Vecino'), findsOneWidget);

      // Ingresar nombre del nuevo cliente
      final nameField = find.widgetWithText(
        TextFormField,
        'Nombre y Apellidos *',
      );
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'Doña Rosa Valdivia');
      await tester.pumpAndSettle();

      // Guardar el nuevo cliente
      await tester.tap(find.text('Registrar Vecino'));
      await tester.pumpAndSettle();

      // La venta a crédito debe haberse completado automáticamente para el nuevo cliente
      expect(fakeVentaService.sentVentas.length, 1);
      final envio = fakeVentaService.sentVentas.first;
      expect(envio.metodoPago, 'Crédito');
      expect(
        fakeClienteService.lastCreated?.nombreCompleto,
        'Doña Rosa Valdivia',
      );
      expect(envio.idCliente, fakeClienteService.lastCreated?.idCliente);
      expect(envio.clienteNombre, 'Doña Rosa Valdivia');

      // Ticket limpio y confirmación de venta
      expect(find.textContaining('Cobrado S/ 5.20 con Crédito'), findsOneWidget);
      expect(find.textContaining('items en cuenta'), findsNothing);
      expect(find.text('×1'), findsNothing);
    },
  );
}
