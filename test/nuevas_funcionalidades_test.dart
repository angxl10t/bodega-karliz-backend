import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bodega_mobile/features/ventas/venta_model.dart';
import 'package:bodega_mobile/features/ventas/venta_en_espera_service.dart';
import 'package:bodega_mobile/features/catalogo/pedido_web_service.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/auth/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. Venta en Espera / Multiticket (Park Cart)', () {
    final productoMock = Producto(
      idProducto: 101,
      nombre: 'Arroz Costeño 1kg',
      precioVenta: 4.80,
      precioCosto: 3.90,
      stockActual: 20.0,
      codigo: 'ARR001',
      nombreCategoria: 'Abarrotes',
    );

    test('Guardar venta en espera actualiza reactivamente el contador y recupera fielmente', () async {
      await VentaEnEsperaService.inicializar();
      expect(VentaEnEsperaService.countNotifier.value, 0);

      final item = CartItem(producto: productoMock, cantidad: 2.0);
      final venta = VentaEnEspera(
        id: 'ticket-1',
        fecha: DateTime.now(),
        etiqueta: 'Cliente Don Mario',
        items: [item],
        metodoPago: 'Efectivo',
        tipoComprobante: 'BOLETA_ELECTRONICA',
        descuentoManualCarrito: 0.60,
        descuentoManualMotivo: 'Cortesía de barrio',
      );

      await VentaEnEsperaService.ponerEnEspera(venta);

      expect(VentaEnEsperaService.ventas.length, 1);
      expect(VentaEnEsperaService.countNotifier.value, 1);
      expect(VentaEnEsperaService.ventas.first.etiqueta, 'Cliente Don Mario');
      expect(VentaEnEsperaService.ventas.first.totalBruto, 9.60);
      expect(VentaEnEsperaService.ventas.first.totalNeto, 9.00);

      final recuperada = await VentaEnEsperaService.recuperar('ticket-1');
      expect(recuperada, isNotNull);
      expect(recuperada!.items.first.producto.nombre, 'Arroz Costeño 1kg');
      expect(recuperada.descuentoManualCarrito, 0.60);
      expect(VentaEnEsperaService.ventas.length, 0);
      expect(VentaEnEsperaService.countNotifier.value, 0);
    });

    test('Eliminar venta en espera remueve el ticket', () async {
      await VentaEnEsperaService.inicializar();
      final venta = VentaEnEspera(
        id: 'ticket-del',
        fecha: DateTime.now(),
        etiqueta: 'Ticket descartable',
        items: [CartItem(producto: productoMock, cantidad: 1.0)],
      );

      await VentaEnEsperaService.ponerEnEspera(venta);
      expect(VentaEnEsperaService.countNotifier.value, 1);

      await VentaEnEsperaService.eliminar('ticket-del');
      expect(VentaEnEsperaService.countNotifier.value, 0);
      expect(VentaEnEsperaService.ventas.isEmpty, true);
    });
  });

  group('2. Descuento de Cortesía / Manual por Ítem y Carrito', () {
    final productoMock = Producto(
      idProducto: 202,
      nombre: 'Leche Gloria Azul 400g',
      precioVenta: 4.20,
      stockActual: 15.0,
      codigo: 'GLO001',
      nombreCategoria: 'Lácteos',
    );

    test('CartItem calcula subtotalBruto y descuenta monto manual respetando clamp a 0', () {
      final item = CartItem(
        producto: productoMock,
        cantidad: 3.0,
        descuentoManual: 1.20,
        descuentoMotivo: 'Redondeo amigable',
      );

      expect(item.subtotalBruto, 12.60);
      expect(item.subtotal, 11.40);
      expect(item.descuentoMotivo, 'Redondeo amigable');

      // Si el descuento excede el precio, no se hace negativo
      item.descuentoManual = 20.00;
      expect(item.subtotal, 0.0);
    });

    test('CartItem serializa y deserializa descuento manual correctamente', () {
      final item = CartItem(
        producto: productoMock,
        cantidad: 2.0,
        descuentoManual: 0.80,
        descuentoMotivo: 'Cortesía vecino',
      );

      final json = item.toJson();
      final restaurado = CartItem.fromJson(json);

      expect(restaurado.producto.nombre, 'Leche Gloria Azul 400g');
      expect(restaurado.cantidad, 2.0);
      expect(restaurado.descuentoManual, 0.80);
      expect(restaurado.descuentoMotivo, 'Cortesía vecino');
      expect(restaurado.subtotal, 7.60);
    });
  });

  group('3. Bandeja de Pedidos Web en el POS', () {
    test('Registrar pedido web notifica reactivamente y permite marcarlo como cargado', () async {
      await PedidoWebService.inicializar();
      expect(PedidoWebService.pedidosPendientesCountNotifier.value, 0);

      final pedido = PedidoWeb(
        idPedido: 'WEB-1001',
        fecha: DateTime.now(),
        nombreCliente: 'María López',
        telefonoCliente: '987654321',
        notas: 'Traer cambio de S/ 50',
        items: const [
          PedidoWebItem(
            idProducto: 101,
            nombre: 'Arroz Costeño 1kg',
            cantidad: 2.0,
            precioUnitario: 4.80,
            subtotal: 9.60,
          ),
        ],
        total: 9.60,
      );

      await PedidoWebService.registrarPedido(pedido);

      expect(PedidoWebService.pedidos.length, 1);
      expect(PedidoWebService.pedidosPendientes.length, 1);
      expect(PedidoWebService.pedidosPendientesCountNotifier.value, 1);

      await PedidoWebService.marcarComoCargadoEnPos('WEB-1001');

      expect(PedidoWebService.pedidos.first.estado, 'CARGADO_EN_POS');
      expect(PedidoWebService.pedidosPendientes.length, 0);
      expect(PedidoWebService.pedidosPendientesCountNotifier.value, 0);

      await PedidoWebService.eliminarPedido('WEB-1001');
      expect(PedidoWebService.pedidos.isEmpty, true);
    });
  });

  group('4. Control de Roles y Modo Cajero Protegido', () {
    test('AuthService cached role detecta cajero vs admin apropiadamente', () {
      AuthService.setCachedRol('CAJERO');
      expect(AuthService.esCajero, true);
      expect(AuthService.esAdmin, false);

      AuthService.setCachedRol('ADMIN');
      expect(AuthService.esCajero, false);
      expect(AuthService.esAdmin, true);

      AuthService.setCachedRol('SUPERADMIN');
      expect(AuthService.esCajero, false);
      expect(AuthService.esAdmin, true);
    });
  });
}
