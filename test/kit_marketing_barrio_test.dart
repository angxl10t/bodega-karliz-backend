import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/core/thermal_ticket_service.dart';
import 'package:bodega_mobile/features/marketing/kit_marketing_barrio_modal.dart';

void main() {
  group('ThermalTicketService - Volante Promocional Multinegocio', () {
    test('generateVolanteBarrioText genera texto culinario para POLLERIA', () {
      final text = ThermalTicketService.generateVolanteBarrioText(
        nombreComercio: 'Pollería Brasa Real',
        urlCatalogo:
            'https://cajaya-pos.onrender.com/#/catalogo?tienda=brasa-real',
        giroNegocio: 'POLLERIA',
        telefono: '999888777',
      );

      expect(text, contains('BRASA REAL'));
      expect(text, contains('PIDE DESDE TU MESA O CASA!'));
      expect(text, contains('ESCANEA NUESTRA CARTA DIGITAL:'));
      expect(text, contains('Pollo a la Brasa y Combos'));
      expect(text, contains('Papas, Cremas y Guarniciones'));
      expect(text, contains('Buen provecho y gracias!'));
    });

    test('generateVolanteBarrioText genera texto culinario para CHIFA', () {
      final text = ThermalTicketService.generateVolanteBarrioText(
        nombreComercio: 'Chifa Dragón Dorado',
        urlCatalogo:
            'https://cajaya-pos.onrender.com/#/catalogo?tienda=dragon-dorado',
        giroNegocio: 'CHIFA',
      );

      expect(text, contains('DRAGON DORADO'));
      expect(text, contains('Chaufa al Wok y Aeropuertos'));
      expect(text, contains('Wantanes, Tipakay y Sopas'));
      expect(text, contains('Buen provecho y gracias!'));
    });

    test('generateVolanteBarrioText mantiene formato de bodega tradicional para BODEGA', () {
      final text = ThermalTicketService.generateVolanteBarrioText(
        nombreComercio: 'Bodega Karliz',
        urlCatalogo:
            'https://cajaya-pos.onrender.com/#/catalogo?tienda=bodega-karliz',
        giroNegocio: 'BODEGA',
      );

      expect(text, contains('VECINO(A), NO HAGAS COLA!'));
      expect(text, contains('ESCANEA NUESTRA TIENDA VIRTUAL:'));
      expect(text, contains('Abarrotes, Bebidas y Golosinas'));
      expect(text, contains('Gracias por apoyar a tu bodega!'));
    });
  });
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

    testWidgets(
      'Renderiza modal adaptado para POLLERIA con carta digital y afiche de salón',
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
                  nombreBodega: 'Brasa & Leña Real',
                  telefono: '999888777',
                  lemaComercial: 'El mejor sabor a la brasa',
                  slugOrId: 'brasa-y-lena-real',
                  giroNegocio: 'POLLERIA',
                ),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 300));

        // Verificar título gastronómico
        expect(find.text('Viralidad & Carta Digital'), findsOneWidget);
        expect(
          find.text('Llena tus mesas y atrae comensales por WhatsApp'),
          findsOneWidget,
        );

        // Verificar pestañas gastronómicas
        expect(find.text('Volante Carta'), findsOneWidget);
        expect(find.text('Afiche Salón / Mesa'), findsOneWidget);
        expect(find.text('Difusión WhatsApp'), findsOneWidget);
        expect(find.text('Referir Colega'), findsOneWidget);

        // Pestaña 1: Volante Carta contiene texto culinario
        expect(find.text('Volante de Mesa y Cuenta'), findsOneWidget);
        expect(find.textContaining('Pollo a la Brasa y Combos'), findsWidgets);

        // Deslizar a Pestaña 2: Afiche Salón / Mesa
        await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.textContaining('PIDE DESDE TU MESA O LLEVA A CASA'),
          findsWidgets,
        );

        // Deslizar a Pestaña 3: Difusión WhatsApp
        await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.textContaining('Mensaje Listo para Clientes & Comensales'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Pollos doraditos, papas crocantes'),
          findsWidgets,
        );
        expect(find.text('ENVIAR CARTA POR WHATSAPP'), findsOneWidget);

        // Deslizar a Pestaña 4: Referir Colega
        await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.textContaining('pollería, chifa o restaurante'),
          findsWidgets,
        );
      },
    );
  });
}
