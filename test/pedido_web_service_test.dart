import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bodega_mobile/features/catalogo/pedido_web_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PedidoWebService.inicializar();
  });

  group('PedidoWebService & PedidoWeb Models', () {
    test('PedidoWeb serialization and deserialization with codigoDisplay', () {
      final item = PedidoWebItem(
        idProducto: 10,
        nombre: 'Gaseosa Inka Kola 500ml',
        cantidad: 2.0,
        precioUnitario: 3.50,
        subtotal: 7.00,
        badge: 'PROMO',
      );

      final pedido = PedidoWeb(
        idPedidoWeb: 42,
        idPedido: 'WEB-98765',
        codigoPedido: '#W-4821',
        fecha: DateTime(2026, 11, 3, 14, 0),
        nombreCliente: 'Carlos Mendoza',
        telefonoCliente: '987654321',
        notas: 'Para recoger a las 5pm',
        items: [item],
        total: 7.00,
        ahorroPromociones: 1.00,
        incluyeRetornables: true,
        estado: 'PENDIENTE',
      );

      expect(pedido.codigoDisplay, '#W-4821');

      final json = pedido.toJson();
      expect(json['idPedidoWeb'], 42);
      expect(json['codigoPedido'], '#W-4821');
      expect(json['idPedido'], 'WEB-98765');
      expect(json['items'], isNotEmpty);

      final decoded = PedidoWeb.fromJson(json);
      expect(decoded.idPedidoWeb, 42);
      expect(decoded.codigoDisplay, '#W-4821');
      expect(decoded.nombreCliente, 'Carlos Mendoza');
      expect(decoded.items.first.nombre, 'Gaseosa Inka Kola 500ml');
      expect(decoded.items.first.subtotal, 7.00);
      expect(decoded.items.first.badge, 'PROMO');
    });

    test('Registrar pedido actualiza conteo de pendientes', () async {
      final item = PedidoWebItem(
        idProducto: 1,
        nombre: 'Pan Bimbo Artesano',
        cantidad: 1.0,
        precioUnitario: 7.50,
        subtotal: 7.50,
      );

      final pedido1 = PedidoWeb(
        idPedido: 'WEB-1',
        codigoPedido: '#W-1001',
        fecha: DateTime.now(),
        nombreCliente: 'Ana Torres',
        items: [item],
        total: 7.50,
        estado: 'PENDIENTE',
      );

      await PedidoWebService.registrarPedido(pedido1);
      expect(PedidoWebService.pedidosPendientesCountNotifier.value, 1);
      expect(PedidoWebService.pedidos.length, 1);
      expect(PedidoWebService.pedidos.first.codigoDisplay, '#W-1001');

      // Marcar como cargado en POS
      await PedidoWebService.marcarComoCargadoEnPos(pedido1.codigoDisplay);
      expect(PedidoWebService.pedidosPendientesCountNotifier.value, 0);
      expect(PedidoWebService.pedidos.first.estado, 'CARGADO_EN_POS');

      // Eliminar
      await PedidoWebService.eliminarPedido(pedido1.codigoDisplay);
      expect(PedidoWebService.pedidos.isEmpty, isTrue);
      expect(PedidoWebService.pedidosPendientesCountNotifier.value, 0);
    });

    test(
      'buscarPedidos filtra localmente por código, cliente o teléfono',
      () async {
        final p1 = PedidoWeb(
          idPedido: 'WEB-1',
          codigoPedido: '#W-4821',
          fecha: DateTime.now(),
          nombreCliente: 'Juan Pérez',
          telefonoCliente: '987111222',
          items: [],
          total: 15.00,
        );

        final p2 = PedidoWeb(
          idPedido: 'WEB-2',
          codigoPedido: '#W-7733',
          fecha: DateTime.now(),
          nombreCliente: 'María Ruiz',
          telefonoCliente: '999888777',
          items: [],
          total: 20.00,
        );

        await PedidoWebService.registrarPedido(p1);
        await PedidoWebService.registrarPedido(p2);

        final resCodigo = await PedidoWebService.buscarPedidos('#W-4821');
        expect(resCodigo.length, 1);
        expect(resCodigo.first.nombreCliente, 'Juan Pérez');

        final resNombre = await PedidoWebService.buscarPedidos('María');
        expect(resNombre.length, 1);
        expect(resNombre.first.codigoDisplay, '#W-7733');

        final resFono = await PedidoWebService.buscarPedidos('111222');
        expect(resFono.length, 1);
        expect(resFono.first.nombreCliente, 'Juan Pérez');
      },
    );
  });
}
