import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/home/bodega_service.dart';

void main() {
  group('BodegaInfo & Subscription Model Tests', () {
    test('BodegaInfo deserializes subscription fields correctly', () {
      final json = {
        'idBodega': 10,
        'nombreComercial': 'Minimarket Los Andes',
        'rucDni': '20601234567',
        'colorPrimario': '#2563EB',
        'plan': 'PRO',
        'estado': true,
        'fechaVencimientoPlan': '2026-11-15T12:00:00Z',
      };

      final info = BodegaInfo.fromJson(json);

      expect(info.idBodega, 10);
      expect(info.nombreComercial, 'Minimarket Los Andes');
      expect(info.plan, 'PRO');
    });

    test('BodegaInfo defaults plan and active state correctly', () {
      final json = {
        'idBodega': 1,
        'nombreComercial': 'Bodega San José',
        'colorPrimario': '#2563EB',
        'plan': 'BASICO',
        'estado': true,
      };

      final info = BodegaInfo.fromJson(json);

      expect(info.plan, 'BASICO');
      expect(info.estado, isTrue);
    });
  });
}
