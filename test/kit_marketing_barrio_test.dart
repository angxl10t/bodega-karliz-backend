import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/marketing/kit_marketing_barrio_modal.dart';

void main() {
  group('KitMarketingBarrioModal - URL y Normalización de Slugs', () {
    test(
      'normalizarSlug convierte acentos, espacios y símbolos a formato slug',
      () {
        expect(
          KitMarketingBarrioModal.normalizarSlug('Bodega Karliz'),
          'bodega-karliz',
        );
        expect(
          KitMarketingBarrioModal.normalizarSlug('Minimarket El Éxito'),
          'minimarket-el-exito',
        );
        expect(
          KitMarketingBarrioModal.normalizarSlug('Bodega San José & Amigos'),
          'bodega-san-jose-amigos',
        );
        expect(
          KitMarketingBarrioModal.normalizarSlug('  Tienda Don Pepe  '),
          'tienda-don-pepe',
        );
        expect(KitMarketingBarrioModal.normalizarSlug(''), '');
      },
    );

    test('buildUrlCatalogo genera la URL oficial de Render para bodega-karliz por defecto', () {
      final url = KitMarketingBarrioModal.buildUrlCatalogo(
        nombreBodega: 'CajaYa POS',
      );
      expect(
        url,
        'https://cajaya-pos.onrender.com/#/catalogo?tienda=bodega-karliz',
      );
    });

    test('buildUrlCatalogo genera la URL correspondiente a Bodega Karliz', () {
      final url = KitMarketingBarrioModal.buildUrlCatalogo(
        nombreBodega: 'Bodega Karliz',
      );
      expect(
        url,
        'https://cajaya-pos.onrender.com/#/catalogo?tienda=bodega-karliz',
      );
    });

    test('buildUrlCatalogo genera la URL dinámica para cualquier bodega PRO independiente', () {
      final url = KitMarketingBarrioModal.buildUrlCatalogo(
        nombreBodega: 'Minimarket Los Olivos',
      );
      expect(
        url,
        'https://cajaya-pos.onrender.com/#/catalogo?tienda=minimarket-los-olivos',
      );
    });

    test('buildUrlCatalogo respeta slugOrId explícito si está presente', () {
      final url = KitMarketingBarrioModal.buildUrlCatalogo(
        slugOrId: 'bodega-karliz',
        nombreBodega: 'Nombre Alternativo',
      );
      expect(
        url,
        'https://cajaya-pos.onrender.com/#/catalogo?tienda=bodega-karliz',
      );
    });

    test('buildUrlCatalogo usa el ID numérico si no hay nombre ni slug', () {
      final url = KitMarketingBarrioModal.buildUrlCatalogo(bodegaId: 7);
      expect(url, 'https://cajaya-pos.onrender.com/#/catalogo?tienda=7');
    });
  });

  group('KitMarketingBarrioModal - Widget Test', () {
    testWidgets(
      'Renderiza modal con sus 4 pestañas y enlaces oficiales Render',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 900,
                width: 800,
                child: KitMarketingBarrioModal(
                  nombreBodega: 'Bodega Karliz',
                  telefono: '987654321',
                  lemaComercial: 'La más surtida de la cuadra',
                  slugOrId: 'bodega-karliz',
                ),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 300));

        // Verificar título principal
        expect(find.text('Viralidad & Marketing de Barrio'), findsOneWidget);

        // Verificar pestañas
        expect(find.text('Volante Térmico'), findsOneWidget);
        expect(find.text('Afiche Vitrina'), findsOneWidget);
        expect(find.text('Difusión WhatsApp'), findsOneWidget);
        expect(find.text('Referir Colega'), findsOneWidget);

        // Pestaña 1: Volante térmico contiene el enlace oficial al catálogo en Render
        expect(find.textContaining('cajaya-pos.onrender.com'), findsWidgets);
        expect(find.textContaining('bodega-karliz'), findsWidgets);

        // Deslizar a Pestaña 2: Afiche Vitrina
        await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.textContaining('VECINO, PIDE DESDE CASA'), findsWidgets);

        // Deslizar a Pestaña 3: Difusión WhatsApp
        await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.textContaining('Mensaje Listo para Grupos del Barrio'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'https://cajaya-pos.onrender.com/#/catalogo?tienda=bodega-karliz',
          ),
          findsWidgets,
        );

        // Deslizar a Pestaña 4: Referir Colega
        await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.textContaining('https://cajaya-pos.onrender.com'),
          findsWidgets,
        );
        expect(find.textContaining('cajaya.pe'), findsNothing);
      },
    );
  });
}
