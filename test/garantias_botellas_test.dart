import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/clientes/garantia_botella_model.dart';
import 'package:bodega_mobile/features/clientes/nueva_garantia_sheet.dart';
import 'package:bodega_mobile/features/clientes/devolver_botella_dialog.dart';
import 'package:bodega_mobile/features/clientes/cliente_model.dart';

void main() {
  group('GarantiaBotella & ResumenGarantias Model Tests', () {
    test(
      'GarantiaBotella deserializes from JSON and computes remaining values',
      () {
        final json = {
          'idGarantia': 10,
          'idBodega': 1,
          'idCliente': 5,
          'nombrePersona': 'Don Pedro',
          'telefono': '987654321',
          'cantidadBotellas': 3,
          'montoGarantia': 6.00,
          'tipoBotella': 'Cerveza 650ml',
          'notas': 'Botellas de Pilsen retornables',
          'estado': 'PENDIENTE',
          'botellasDevueltas': 1,
          'montoDevuelto': 2.00,
          'botellasRestantes': 2,
          'montoRestante': 4.00,
          'fechaRegistro': '2026-11-02T10:00:00Z',
        };

        final g = GarantiaBotella.fromJson(json);

        expect(g.idGarantia, 10);
        expect(g.nombrePersona, 'Don Pedro');
        expect(g.cantidadBotellas, 3);
        expect(g.montoGarantia, 6.00);
        expect(g.botellasDevueltas, 1);
        expect(g.botellasRestantes, 2);
        expect(g.montoDevuelto, 2.00);
        expect(g.montoRestante, 4.00);
        expect(g.estaPendiente, isTrue);
        expect(g.estaDevuelto, isFalse);

        final map = g.toJson();
        expect(map['idGarantia'], 10);
        expect(map['nombrePersona'], 'Don Pedro');
        expect(map['cantidadBotellas'], 3);
      },
    );

    test('ResumenGarantias deserializes financial and bottles metrics', () {
      final json = {
        'totalDineroCustodia': 24.00,
        'botellasPendientes': 12,
        'personasPendientes': 5,
        'totalDevueltoMes': 50.00,
        'botellasDevueltasMes': 25,
      };

      final r = ResumenGarantias.fromJson(json);

      expect(r.totalDineroCustodia, 24.00);
      expect(r.botellasPendientes, 12);
      expect(r.personasPendientes, 5);
      expect(r.totalDevueltoMes, 50.00);
      expect(r.botellasDevueltasMes, 25);
    });
  });

  group('NuevaGarantiaSheet Widget Tests', () {
    testWidgets('Renders fields for person, bottles count and deposit money', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));

      final clientes = [
        Cliente(
          idCliente: 1,
          nombreCompleto: 'Juan Pérez',
          telefono: '987111222',
          limiteCredito: 200,
          saldoDeudor: 0,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NuevaGarantiaSheet(
              clientesDisponibles: clientes,
              onGuardado: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dejar Dinero por Botellas'), findsOneWidget);
      expect(find.text('Nombre de la Persona *'), findsOneWidget);
      expect(find.text('Cantidad de Botellas'), findsOneWidget);
      expect(find.text('Registrar Garantía de Botellas'), findsOneWidget);
    });
  });

  group('DevolverBotellaDialog Widget Tests', () {
    testWidgets('Renders return dialog with correct refund calculation', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));

      const g = GarantiaBotella(
        idGarantia: 1,
        nombrePersona: 'Carlos Santillán',
        cantidadBotellas: 2,
        montoGarantia: 4.00,
        botellasRestantes: 2,
        montoRestante: 4.00,
        tipoBotella: 'Cerveza 650ml',
        estado: 'PENDIENTE',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DevolverBotellaDialog(garantia: g, onDevuelto: () {}),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Devolución de Botellas'), findsOneWidget);
      expect(find.text('Carlos Santillán'), findsOneWidget);
      expect(find.text('S/ 4.00'), findsOneWidget);
      expect(find.text('Entregar S/ 4.00 y Recibir Envase'), findsOneWidget);
    });
  });
}
