import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bodega_mobile/core/theme.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/ventas/widgets/mostrador_calculadora_view.dart';

Widget _createMostradorApp({
  required List<Producto> productos,
  required VoidCallback onVolverAPos,
  bool isDark = false,
}) {
  return MaterialApp(
    theme: isDark ? AppTheme.buildDarkTheme() : AppTheme.buildLightTheme(),
    home: Scaffold(
      body: MostradorCalculadoraView(
        productosDisponibles: productos,
        onVolverAPos: onVolverAPos,
        isDark: isDark,
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
        _createMostradorApp(
          productos: dummyProductos,
          onVolverAPos: () {},
        ),
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

  testWidgets(
    'Cálculo de vuelto con billetes rápidos en efectivo',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _createMostradorApp(
          productos: dummyProductos,
          onVolverAPos: () {},
        ),
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
    },
  );
}
