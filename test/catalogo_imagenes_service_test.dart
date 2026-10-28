import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/core/catalogo_imagenes_service.dart';

void main() {
  group('CatalogoImagenesService & Packshots Precision Tests', () {
    test('Diferenciación exacta por tamaño en bebidas (500ml vs 3L)', () {
      final coca500 = CatalogoImagenesService.buscarSugerencia(nombre: 'Coca Cola 500ml');
      expect(coca500, isNotNull);
      expect(coca500!.id, equals('coca_cola_500ml'));
      expect(coca500.imagenUrl, contains('coca_cola_500ml.png'));

      final coca3l = CatalogoImagenesService.buscarSugerencia(nombre: 'Coca Cola 3 Litros');
      expect(coca3l, isNotNull);
      expect(coca3l!.id, equals('coca_cola_3l'));
      expect(coca3l.imagenUrl, contains('coca_cola_3l.png'));

      final inka500 = CatalogoImagenesService.buscarSugerencia(nombre: 'Inca Kola 500ml');
      expect(inka500, isNotNull);
      expect(inka500!.id, equals('inka_kola_500ml'));
      expect(inka500.imagenUrl, contains('inka_kola_500ml.png'));

      final inka3l = CatalogoImagenesService.buscarSugerencia(nombre: 'Inca Kola 3L');
      expect(inka3l, isNotNull);
      expect(inka3l!.id, equals('inka_kola_3l'));
      expect(inka3l.imagenUrl, contains('inka_kola_3l.png'));
    });

    test('Diferenciación de Fanta y Sprite 500ml vs 3L', () {
      final fanta500 = CatalogoImagenesService.buscarSugerencia(nombre: 'Fanta Naranja 500ml');
      expect(fanta500, isNotNull);
      expect(fanta500!.id, equals('fanta_500ml'));

      final fanta3l = CatalogoImagenesService.buscarSugerencia(nombre: 'Fanta 3 Litros');
      expect(fanta3l, isNotNull);
      expect(fanta3l!.id, equals('fanta_3l'));

      final sprite500 = CatalogoImagenesService.buscarSugerencia(nombre: 'Sprite 500ml');
      expect(sprite500, isNotNull);
      expect(sprite500!.id, equals('sprite_500ml'));

      final sprite3l = CatalogoImagenesService.buscarSugerencia(nombre: 'Sprite 3L');
      expect(sprite3l, isNotNull);
      expect(sprite3l!.id, equals('sprite_3l'));
    });

    test('Diferenciación exacta en snacks y golosinas', () {
      final lays = CatalogoImagenesService.buscarSugerencia(nombre: 'Papas Lays 140g');
      expect(lays, isNotNull);
      expect(lays!.id, equals('lays_clasicas'));
      expect(lays.nombre, contains('140g'));

      final doritos = CatalogoImagenesService.buscarSugerencia(nombre: 'Doritos 45g');
      expect(doritos, isNotNull);
      expect(doritos!.id, equals('doritos_queso'));

      final cheeseTris = CatalogoImagenesService.buscarSugerencia(nombre: 'Cheese Tris 44g');
      expect(cheeseTris, isNotNull);
      expect(cheeseTris!.id, equals('cheese_tris'));

      final cuates = CatalogoImagenesService.buscarSugerencia(nombre: 'Cuates Picantes 100g');
      expect(cuates, isNotNull);
      expect(cuates!.id, equals('cuates_picantes'));
    });

    test('Búsqueda exacta por Código de Barras (EAN-13)', () {
      final item = CatalogoImagenesService.buscarSugerencia(codigoBarras: '7750106000025');
      expect(item, isNotNull);
      expect(item!.id, equals('coca_cola_500ml'));

      final inka = CatalogoImagenesService.buscarSugerencia(codigoBarras: '7750106001010');
      expect(inka, isNotNull);
      expect(inka!.id, equals('inka_kola_500ml'));
    });
  });
}
