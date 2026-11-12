import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/home/bodega_service.dart';
import 'package:bodega_mobile/features/fiscal/monitor_nuevo_rus_modal.dart';

void main() {
  group('Monitor Nuevo RUS & Régimen Fiscal Tests', () {
    test('ResumenNuevoRus parsea correctamente datos de Categoría 1 (hasta S/ 5,000)', () {
      final json = {
        'anio': 2026,
        'mes': 11,
        'periodoNombre': 'Noviembre 2026',
        'esNuevoRus': true,
        'regimenTributario': 'NUEVO_RUS',
        'totalVentasMes': 3450.50,
        'totalComprasMes': 1800.00,
        'montoDeterminante': 3450.50,
        'categoriaActual': 'CATEGORIA_1',
        'categoriaNombre': 'Categoría 1 (Hasta S/ 5,000)',
        'cuotaMensualEstimada': 20.00,
        'limiteCat1': 5000.00,
        'limiteCat2': 8000.00,
        'restanteCat1': 1549.50,
        'restanteCat2': 4549.50,
        'porcentajeCat1': 69.01,
        'porcentajeCat2': 43.13,
        'estadoSemaforo': 'VERDE',
        'mensajeDiagnostico': 'Negocio en Categoría 1',
        'advertencia': null,
        'sugerenciaPagoSunat': 'Pagar en agente BCP con Formulario 1611',
      };

      final resumen = ResumenNuevoRus.fromJson(json);

      expect(resumen.anio, equals(2026));
      expect(resumen.mes, equals(11));
      expect(resumen.periodoNombre, equals('Noviembre 2026'));
      expect(resumen.esNuevoRus, isTrue);
      expect(resumen.regimenTributario, equals('NUEVO_RUS'));
      expect(resumen.totalVentasMes, equals(3450.50));
      expect(resumen.totalComprasMes, equals(1800.00));
      expect(resumen.montoDeterminante, equals(3450.50));
      expect(resumen.categoriaActual, equals('CATEGORIA_1'));
      expect(resumen.cuotaMensualEstimada, equals(20.00));
      expect(resumen.restanteCat1, equals(1549.50));
      expect(resumen.restanteCat2, equals(4549.50));
      expect(resumen.estadoSemaforo, equals('VERDE'));
      expect(resumen.advertencia, isNull);
    });

    test(
      'ResumenNuevoRus parsea correctamente datos de Categoría 2 y advertencia',
      () {
        final json = {
          'anio': 2026,
          'mes': 11,
          'periodoNombre': 'Noviembre 2026',
          'esNuevoRus': true,
          'regimenTributario': 'NUEVO_RUS',
          'totalVentasMes': 4200.00,
          'totalComprasMes': 7400.00, // Mayor compras que ventas
          'montoDeterminante': 7400.00,
          'categoriaActual': 'CATEGORIA_2',
          'categoriaNombre': 'Categoría 2 (Hasta S/ 8,000)',
          'cuotaMensualEstimada': 50.00,
          'limiteCat1': 5000.00,
          'limiteCat2': 8000.00,
          'restanteCat1': 0.00,
          'restanteCat2': 600.00,
          'porcentajeCat1': 100.00,
          'porcentajeCat2': 92.50,
          'estadoSemaforo': 'ROJO',
          'mensajeDiagnostico': 'Cerca del tope máximo',
          'advertencia': 'Te quedan menos de S/ 600.00',
          'sugerenciaPagoSunat': 'Pagar en agente BCP',
        };

        final resumen = ResumenNuevoRus.fromJson(json);

        expect(resumen.categoriaActual, equals('CATEGORIA_2'));
        expect(resumen.cuotaMensualEstimada, equals(50.00));
        expect(resumen.montoDeterminante, equals(7400.00));
        expect(resumen.restanteCat1, equals(0.00));
        expect(resumen.restanteCat2, equals(600.00));
        expect(resumen.estadoSemaforo, equals('ROJO'));
        expect(resumen.advertencia, equals('Te quedan menos de S/ 600.00'));
      },
    );

    test(
      'ResumenNuevoRus parsea correctamente bodega informal / independiente',
      () {
        final jsonInformal = {
          'anio': 2026,
          'mes': 11,
          'periodoNombre': 'Noviembre 2026',
          'esNuevoRus': false,
          'regimenTributario': 'INFORMAL',
          'totalVentasMes': 2100.00,
          'totalComprasMes': 1300.00,
          'montoDeterminante': 2100.00,
          'categoriaActual': 'INFORMAL',
          'categoriaNombre': 'Bodega Independiente (Sin SUNAT)',
          'cuotaMensualEstimada': 0.00,
          'limiteCat1': 5000.00,
          'limiteCat2': 8000.00,
          'restanteCat1': 2900.00,
          'restanteCat2': 5900.00,
          'porcentajeCat1': 42.00,
          'porcentajeCat2': 26.25,
          'estadoSemaforo': 'NEUTRO',
          'mensajeDiagnostico':
              'Bodega no sujeta a obligaciones del Nuevo RUS.',
          'advertencia': null,
          'sugerenciaPagoSunat': null,
        };

        final resumen = ResumenNuevoRus.fromJson(jsonInformal);

        expect(resumen.esNuevoRus, isFalse);
        expect(resumen.regimenTributario, equals('INFORMAL'));
        expect(resumen.categoriaActual, equals('INFORMAL'));
        expect(resumen.cuotaMensualEstimada, equals(0.00));
        expect(resumen.estadoSemaforo, equals('NEUTRO'));
      },
    );

    test('BodegaInfo detecta esNuevoRus de forma consistente', () {
      final jsonRus = {
        'idBodega': 1,
        'nombreComercial': 'Bodega Karliz',
        'regimenTributario': 'NUEVO_RUS',
        'plan': 'PRO',
        'colorPrimario': '#2563EB',
        'estado': true,
      };
      final infoRus = BodegaInfo.fromJson(jsonRus);
      expect(infoRus.regimenTributario, equals('NUEVO_RUS'));
      expect(infoRus.esNuevoRus, isTrue);

      final jsonInformal = {
        'idBodega': 2,
        'nombreComercial': 'Bodega Doña Rosa',
        'regimenTributario': 'INFORMAL',
        'plan': 'BASICO',
        'colorPrimario': '#2563EB',
        'estado': true,
      };
      final infoInformal = BodegaInfo.fromJson(jsonInformal);
      expect(infoInformal.regimenTributario, equals('INFORMAL'));
      expect(infoInformal.esNuevoRus, isFalse);

      final jsonDefault = {
        'idBodega': 3,
        'nombreComercial': 'Bodega La Esquina',
        'plan': 'BASICO',
        'colorPrimario': '#2563EB',
        'estado': true,
      };
      final infoDefault = BodegaInfo.fromJson(jsonDefault);
      expect(infoDefault.regimenTributario, equals('NUEVO_RUS'));
      expect(infoDefault.esNuevoRus, isTrue);
    });

    testWidgets('MonitorNuevoRusModal renderiza estructura de diálogo', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => MonitorNuevoRusModal.show(context),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Frente Fiscal & Tributario'), findsOneWidget);
      expect(
        find.text('Realidad del bodeguero peruano • Ley N° 30877'),
        findsOneWidget,
      );
    });
  });
}
