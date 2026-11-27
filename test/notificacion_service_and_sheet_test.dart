import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/core/notificaciones/in_app_notification_banner.dart';
import 'package:bodega_mobile/core/notificaciones/notificacion_service.dart';
import 'package:bodega_mobile/core/notificaciones/notificaciones_sheet.dart';
import 'package:bodega_mobile/core/notificaciones/notificaciones_campana_button.dart';

void main() {
  setUp(() {
    NotificacionService.resetSession();
  });

  tearDown(() {
    NotificacionService.resetSession();
  });

  group('NotificacionItem & NotificacionService Unit Tests', () {
    test('NotificacionItem parses correctly from JSON', () {
      final json = {
        'idNotificacion': 101,
        'idBodega': 1,
        'idUsuarioDestinatario': 5,
        'rolDestinatario': 'ADMIN',
        'tipo': 'STOCK_CRITICO',
        'titulo': '⚠️ Stock Crítico: Inka Kola 500ml',
        'mensaje': 'Quedan 2 unidades en almacén.',
        'metadataJson':
            '{"idProducto":12,"nombre":"Inka Kola 500ml","stockActual":2}',
        'prioridad': 'ALTA',
        'leido': false,
        'fechaCreacion': '2026-11-27T15:00:00Z',
      };

      final item = NotificacionItem.fromJson(json);

      expect(item.idNotificacion, 101);
      expect(item.idBodega, 1);
      expect(item.idUsuarioDestinatario, 5);
      expect(item.rolDestinatario, 'ADMIN');
      expect(item.tipo, 'STOCK_CRITICO');
      expect(item.esStockCritico, isTrue);
      expect(item.esPedidoWeb, isFalse);
      expect(item.titulo, '⚠️ Stock Crítico: Inka Kola 500ml');
      expect(item.prioridad, 'ALTA');
      expect(item.leido, isFalse);
      expect(item.metadata?['idProducto'], 12);
    });

    test('NotificacionItem Nuevo Pedido Web identifies correctly', () {
      final json = {
        'idNotificacion': 102,
        'idBodega': 1,
        'rolDestinatario': 'TODOS',
        'tipo': 'NUEVO_PEDIDO_WEB',
        'titulo': '¡Nuevo Pedido Web #W-1042!',
        'mensaje': 'Cliente: Carlos • Total: S/ 25.50',
        'prioridad': 'ALTA',
        'leido': false,
        'fechaCreacion': '2026-11-27T15:10:00Z',
      };

      final item = NotificacionItem.fromJson(json);

      expect(item.esPedidoWeb, isTrue);
      expect(item.esStockCritico, isFalse);
      expect(item.rolDestinatario, 'TODOS');
    });

    test('NotificacionService updates list and unread count', () {
      final item1 = NotificacionItem(
        idNotificacion: 1,
        idBodega: 1,
        rolDestinatario: 'CAJERO',
        tipo: 'NUEVO_PEDIDO_WEB',
        titulo: 'Nuevo Pedido 1',
        mensaje: 'Msg 1',
        leido: false,
        fechaCreacion: DateTime.now(),
      );

      final item2 = NotificacionItem(
        idNotificacion: 2,
        idBodega: 1,
        rolDestinatario: 'ADMIN',
        tipo: 'STOCK_CRITICO',
        titulo: 'Stock Bajo 2',
        mensaje: 'Msg 2',
        leido: true,
        fechaCreacion: DateTime.now(),
      );

      NotificacionService.notificacionesNotifier.value = [item1, item2];
      NotificacionService.noLeidasCountNotifier.value = 1;

      expect(NotificacionService.notificacionesNotifier.value.length, 2);
      expect(NotificacionService.noLeidasCountNotifier.value, 1);
    });
  });

  group('Notificaciones UI Widget Tests', () {
    testWidgets('NotificacionesCampanaButton renders bell and badge', (
      tester,
    ) async {
      NotificacionService.noLeidasCountNotifier.value = 3;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: NotificacionesCampanaButton())),
        ),
      );

      expect(find.byType(NotificacionesCampanaButton), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('NotificacionesSheet renders tabs and notification items', (
      tester,
    ) async {
      final itemPedido = NotificacionItem(
        idNotificacion: 10,
        idBodega: 1,
        rolDestinatario: 'TODOS',
        tipo: 'NUEVO_PEDIDO_WEB',
        titulo: '¡Nuevo Pedido Web #W-9999!',
        mensaje: 'Cliente Juan • S/ 50.00',
        leido: false,
        fechaCreacion: DateTime.now(),
      );

      final itemStock = NotificacionItem(
        idNotificacion: 11,
        idBodega: 1,
        rolDestinatario: 'ADMIN',
        tipo: 'STOCK_CRITICO',
        titulo: '⚠️ Stock Crítico: Arroz Costeño',
        mensaje: 'Queda 1 bolsa en mostrador.',
        leido: true,
        fechaCreacion: DateTime.now(),
      );

      NotificacionService.notificacionesNotifier.value = [
        itemPedido,
        itemStock,
      ];
      NotificacionService.noLeidasCountNotifier.value = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => NotificacionesSheet.show(ctx),
                child: const Text('Abrir Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Centro de Alertas'), findsOneWidget);
      expect(find.text('Todas'), findsOneWidget);
      expect(find.text('Pedidos Web'), findsOneWidget);
      expect(find.text('Stock Crítico'), findsOneWidget);
      expect(find.text('¡Nuevo Pedido Web #W-9999!'), findsOneWidget);
      expect(find.text('⚠️ Stock Crítico: Arroz Costeño'), findsOneWidget);
    });

    testWidgets(
      'InAppNotificationBanner shows, dismisses and handles rapid calls without exception',
      (tester) async {
        final notif = NotificacionItem(
          idNotificacion: 99,
          idBodega: 1,
          rolDestinatario: 'TODOS',
          tipo: 'NUEVO_PEDIDO_WEB',
          titulo: '¡Nuevo Pedido Web #W-5555!',
          mensaje: 'Total: S/ 80.00',
          leido: false,
          fechaCreacion: DateTime.now(),
        );

        late BuildContext testContext;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) {
                  testContext = ctx;
                  return const Text('Pantalla Principal');
                },
              ),
            ),
          ),
        );

        // Primer llamado
        InAppNotificationBanner.show(testContext, notif);
        await tester.pump();

        expect(find.text('¡Nuevo Pedido Web #W-5555!'), findsOneWidget);

        // Segundo llamado inmediato (reemplazo limpio sin fugas ni excepciones)
        InAppNotificationBanner.show(testContext, notif);
        await tester.pump();

        expect(find.text('¡Nuevo Pedido Web #W-5555!'), findsOneWidget);

        // Descarte explícito
        InAppNotificationBanner.dismiss();
        await tester.pump();

        expect(find.text('¡Nuevo Pedido Web #W-5555!'), findsNothing);

        // Descarte redundante sin error
        expect(() => InAppNotificationBanner.dismiss(), returnsNormally);
      },
    );
  });
}
