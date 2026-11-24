import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:bodega_mobile/features/catalogo/catalogo_publico_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'CatalogoPublicoScreen - Mockup V2 UI Enhancements (Rating, Stories, Payment Selector & Returnable Bottle Assistant)',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final rawJson = File('test/real_catalog_data.json')
          .readAsStringSync(encoding: utf8);

      final mockClient = MockClient((request) async {
        return http.Response(
          rawJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: CatalogoPublicoScreen(
            tiendaSlug: 'bodega-karliz',
            httpClient: mockClient,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verificar rating badge en el header
      expect(find.text('4.9 (184)'), findsOneWidget);
      expect(find.byIcon(LucideIcons.star), findsWidgets);

      // 2. Verificar historias / stories circulares
      expect(find.text('Gaseosas'), findsWidgets);
      expect(find.text('Snacks Snax'), findsWidgets);

      // 3. Tocar en Story de Gaseosas para filtrar
      await tester.tap(find.text('Gaseosas').first);
      await tester.pumpAndSettle();

      // 4. Agregar una cerveza retornable al carrito para probar el asistente de envases
      final pilsenFinder = find.textContaining('Pilsen Callao 630ml');
      if (pilsenFinder.evaluate().isNotEmpty) {
        await tester.tap(pilsenFinder.first);
        await tester.pumpAndSettle();

        final agregarBtn = find.text('Agregar al Pedido');
        if (agregarBtn.evaluate().isNotEmpty) {
          await tester.tap(agregarBtn.first);
          await tester.pumpAndSettle();
        }
      } else {
        // Si no está filtrada por gaseosa, resetear filtro tocando nuevamente
        await tester.tap(find.text('Gaseosas').first);
        await tester.pumpAndSettle();

        final firstProd = find.text('Disponible en tienda');
        if (firstProd.evaluate().isEmpty) {
          // Tap primer producto disponible
          final cardFinder = find.byIcon(LucideIcons.plus).first;
          await tester.tap(cardFinder);
          await tester.pumpAndSettle();
        }
      }

      // 5. Abrir el Carrito Modal
      final verPedidoBtn = find.text('Ver Pedido');
      expect(verPedidoBtn, findsOneWidget);
      await tester.tap(verPedidoBtn);
      await tester.pumpAndSettle();

      // 6. Verificar selector de método de pago en el modal
      expect(find.text('Método de Pago'), findsOneWidget);
      expect(find.text('Yape'), findsOneWidget);
      expect(find.text('Plin'), findsOneWidget);
      expect(find.text('Efectivo'), findsOneWidget);
      expect(find.text('Tarjeta'), findsOneWidget);

      // Tocar en Efectivo
      await tester.tap(find.text('Efectivo'));
      await tester.pumpAndSettle();

      // Verificar que el placeholder del campo de notas se adapte al vuelto en efectivo
      expect(
        find.textContaining('¿Con cuánto pagas?'),
        findsOneWidget,
      );

      // Tocar en Yape nuevamente
      await tester.tap(find.text('Yape'));
      await tester.pumpAndSettle();

      // 7. Si hay botellas retornables, verificar asistente interactivo
      final canjeBtn = find.text('Canje (S/ 0.00)');
      if (canjeBtn.evaluate().isNotEmpty) {
        expect(canjeBtn, findsOneWidget);
        expect(find.text('Garantía (+S/ 2.00)'), findsOneWidget);

        // Alternar a Garantía
        await tester.tap(find.text('Garantía (+S/ 2.00)'));
        await tester.pumpAndSettle();

        // Verificar que aparezca el renglón de garantía en el resumen financiero
        expect(find.textContaining('Garantía Envases'), findsOneWidget);

        // Volver a Canje
        await tester.tap(find.text('Canje (S/ 0.00)'));
        await tester.pumpAndSettle();
      }

      // 8. Botón Pedir por WhatsApp está presente
      expect(find.text('Pedir por WhatsApp'), findsWidgets);
    },
  );
}
