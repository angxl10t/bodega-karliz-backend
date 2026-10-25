import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bodega_mobile/core/api_client.dart';
import 'package:bodega_mobile/features/dashboard/dashboard_bi_model.dart';
import 'package:bodega_mobile/features/dashboard/dashboard_bi_service.dart';
import 'package:bodega_mobile/features/dashboard/dashboard_bi_screen.dart';
import 'package:bodega_mobile/core/csv_exporter.dart';

class FakeHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  FakeHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'jwt_token': 'test_token'});
    SharedPreferences.setMockInitialValues({});
  });

  group('Business Intelligence & Dashboard BI Tests', () {
    test('Deserialización y Serialización completa de DashboardBiData', () {
      final jsonMock = {
        'diasAnalizados': 30,
        'totalVentas': 12500.50,
        'totalCostos': 8750.25,
        'margenBrutoSoles': 3750.25,
        'porcentajeMargenBruto': 30.0,
        'ticketPromedioHoy': 22.50,
        'ticketPromedioSemanal': 24.80,
        'ticketPromedioPeriodo': 23.15,
        'cantidadVentasHoy': 15,
        'cantidadVentasPeriodo': 540,
        'productosEstrella': [
          {
            'idProducto': 101,
            'nombre': 'Inca Kola 3L descartable',
            'codigo': 'BEB-001',
            'categoria': 'Bebidas',
            'imagenUrl': 'https://example.com/ik3l.jpg',
            'unidadesVendidas': 85.0,
            'totalVentas': 1147.50,
            'costoTotal': 807.50,
            'margenBrutoSoles': 340.00,
            'porcentajeMargen': 29.6,
          }
        ],
        'productosHueso': [
          {
            'idProducto': 202,
            'nombre': 'Salsa Barbacoa Gourmet 500g',
            'codigo': 'ABA-099',
            'categoria': 'Salsas',
            'imagenUrl': null,
            'stockActual': 12.0,
            'precioCosto': 8.50,
            'capitalInmovilizado': 102.00,
            'diasSinVentas': 30,
            'accionRecomendada': 'Combo con Salchichas o 2x1',
          }
        ],
        'totalCapitalInmovilizado': 102.00,
        'totalProductosHueso': 1,
        'distribucionHoraria': [
          {
            'hora': 19,
            'etiquetaHora': '19:00 - 20:00',
            'cantidadTickets': 48,
            'totalVentas': 1150.00,
            'esPico': true,
          },
          {
            'hora': 14,
            'etiquetaHora': '14:00 - 15:00',
            'cantidadTickets': 5,
            'totalVentas': 95.00,
            'esPico': false,
          }
        ],
        'horaPicoMaxima': '19:00 a 20:00',
        'horaValleMinima': '14:00 a 15:00',
        'recomendacionTurnos': 'Reforzar atención de caja entre 19:00 y 20:00.',
      };

      final data = DashboardBiData.fromJson(jsonMock);

      expect(data.diasAnalizados, equals(30));
      expect(data.totalVentas, equals(12500.50));
      expect(data.margenBrutoSoles, equals(3750.25));
      expect(data.porcentajeMargenBruto, equals(30.0));
      expect(data.ticketPromedioHoy, equals(22.50));
      expect(data.productosEstrella.length, equals(1));
      expect(data.productosEstrella.first.nombre, equals('Inca Kola 3L descartable'));
      expect(data.productosEstrella.first.margenBrutoSoles, equals(340.00));

      expect(data.productosHueso.length, equals(1));
      expect(data.productosHueso.first.capitalInmovilizado, equals(102.00));
      expect(data.productosHueso.first.accionRecomendada, contains('Combo'));

      expect(data.distribucionHoraria.length, equals(2));
      expect(data.distribucionHoraria.first.esPico, isTrue);
      expect(data.horaPicoMaxima, equals('19:00 a 20:00'));

      // Verificar serialización simétrica a JSON
      final mapOut = data.toJson();
      expect(mapOut['diasAnalizados'], equals(30));
      expect(mapOut['totalVentas'], equals(12500.50));
      expect(mapOut['horaPicoMaxima'], equals('19:00 a 20:00'));
    });

    test('Cálculo de Rentabilidad Real y Margen Bruto Porcentual', () {
      const double venta = 1000.0;
      const double costo = 720.0;
      const double margen = venta - costo;
      final double porcentaje = (margen / venta) * 100;

      expect(margen, equals(280.0));
      expect(porcentaje, closeTo(28.0, 0.01));
    });

    test('Generador de CSV Ejecutivo incluye KPIs, Estrellas, Huesos y Horas Pico', () {
      final mockData = DashboardBiData(
        diasAnalizados: 30,
        totalVentas: 5000.00,
        totalCostos: 3500.00,
        margenBrutoSoles: 1500.00,
        porcentajeMargenBruto: 30.0,
        ticketPromedioHoy: 18.00,
        ticketPromedioSemanal: 19.50,
        ticketPromedioPeriodo: 20.00,
        cantidadVentasHoy: 10,
        cantidadVentasPeriodo: 250,
        productosEstrella: [
          ProductoEstrella(
            idProducto: 1,
            nombre: 'Arroz Costeño 1kg',
            codigo: 'ARR-01',
            categoria: 'Abarrotes',
            unidadesVendidas: 100,
            totalVentas: 480.0,
            costoTotal: 360.0,
            margenBrutoSoles: 120.0,
            porcentajeMargen: 25.0,
          ),
        ],
        productosHueso: [
          ProductoHueso(
            idProducto: 2,
            nombre: 'Aceite de Oliva 500ml',
            codigo: 'ACE-99',
            categoria: 'Abarrotes',
            stockActual: 5,
            precioCosto: 25.0,
            capitalInmovilizado: 125.0,
            diasSinVentas: 45,
            accionRecomendada: 'Armar combo o descuento',
          ),
        ],
        totalCapitalInmovilizado: 125.00,
        totalProductosHueso: 1,
        distribucionHoraria: [
          HorarioPico(
            hora: 20,
            etiquetaHora: '20:00 - 21:00',
            cantidadTickets: 30,
            totalVentas: 600.0,
            esPico: true,
          ),
        ],
        horaPicoMaxima: '20:00 a 21:00',
        horaValleMinima: '15:00 a 16:00',
        recomendacionTurnos: 'Turno reforzado a las 20:00.',
      );

      final csv = CsvExporter.generarCsvDashboardBi(mockData);

      expect(csv, contains('REPORTE EJECUTIVO BI Y RENTABILIDAD CAJAYA'));
      expect(csv, contains('Margen Bruto de Ganancia (PEN),1500.00'));
      expect(csv, contains('Margen Bruto Porcentual (%),30.0%'));
      expect(csv, contains('--- PRODUCTOS ESTRELLA (TOP RENTABILIDAD Y ROTACION) ---'));
      expect(csv, contains('Arroz Costeño 1kg'));
      expect(csv, contains('--- PRODUCTOS HUESO (SIN VENTAS / CAPITAL INMOVILIZADO) ---'));
      expect(csv, contains('Aceite de Oliva 500ml'));
      expect(csv, contains('--- DISTRIBUCION HORARIA Y AFLUENCIA (24 HORAS) ---'));
      expect(csv, contains('20:00 - 21:00'));
    });

    test('DashboardBiService retorna 24 horas y estructura limpia por defecto cuando no hay red ni cache', () async {
      SharedPreferences.setMockInitialValues({});
      final service = DashboardBiService();

      final res = await service.obtenerDashboardBi(dias: 30);

      expect(res.diasAnalizados, equals(30));
      expect(res.totalVentas, equals(0.0));
      expect(res.distribucionHoraria.length, equals(24));
      expect(res.distribucionHoraria[0].etiquetaHora, equals('00:00 - 01:00'));
      expect(res.distribucionHoraria[23].etiquetaHora, equals('23:00 - 00:00'));
    });

    testWidgets('DashboardBiScreen renderiza cabecera, selector de días y acciones correctamente', (tester) async {
      SharedPreferences.setMockInitialValues({});

      final fakeClient = FakeHttpClient((request) async {
        return http.Response(
          jsonEncode({
            'diasAnalizados': 30,
            'totalVentas': 5000.0,
            'totalCostos': 3500.0,
            'margenBrutoSoles': 1500.0,
            'porcentajeMargenBruto': 30.0,
            'ticketPromedioHoy': 18.0,
            'ticketPromedioSemanal': 19.5,
            'ticketPromedioPeriodo': 20.0,
            'cantidadVentasHoy': 10,
            'cantidadVentasPeriodo': 250,
            'productosEstrella': [],
            'productosHueso': [],
            'totalCapitalInmovilizado': 0.0,
            'totalProductosHueso': 0,
            'distribucionHoraria': [],
            'horaPicoMaxima': '19:00 a 20:00',
            'horaValleMinima': '14:00 a 15:00',
            'recomendacionTurnos': 'Horario normal.',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final testService = DashboardBiService(apiClient: ApiClient(client: fakeClient));

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardBiScreen(service: testService),
        ),
      );

      // Procesar carga asíncrona
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Analítica de Negocio & BI'), findsOneWidget);
      expect(find.text('Hoy'), findsAtLeastNWidgets(1));
      expect(find.text('7 Días'), findsOneWidget);
      expect(find.text('30 Días'), findsOneWidget);
      expect(find.text('90 Días'), findsOneWidget);

      // Verificar secciones principales
      expect(find.text('Métricas de Rentabilidad Real'), findsOneWidget);
      expect(find.text('Mapa de Calor de Horarios Pico'), findsOneWidget);
      expect(find.text('Reporte de Rotación Táctico'), findsOneWidget);
    });
  });
}
