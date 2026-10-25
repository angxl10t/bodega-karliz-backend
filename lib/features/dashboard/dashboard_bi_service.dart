import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../../core/csv_exporter.dart';
import 'dashboard_bi_model.dart';

class DashboardBiService {
  static final DashboardBiService instance = DashboardBiService._();
  DashboardBiService._({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();
  factory DashboardBiService({ApiClient? apiClient}) {
    if (apiClient != null) {
      return DashboardBiService._(apiClient: apiClient);
    }
    return instance;
  }

  final ApiClient _apiClient;

  /// Obtiene los datos consolidados de rentabilidad real, productos estrella/hueso
  /// y mapa de calor de horarios pico desde el servidor con fallback resiliente offline en cache.
  Future<DashboardBiData> obtenerDashboardBi({int dias = 30}) async {
    final cacheKey = 'cajaya_cache_dashboard_bi_$dias';
    try {
      final response = await _apiClient.get('/analytics/dashboard-bi?dias=$dias');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        // Guardar en cache local para resiliencia offline
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(data));
        return DashboardBiData.fromJson(data);
      }
    } catch (_) {
      // Ignorar para recurrir a cache offline
    }

    // Fallback a cache local persistido
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(cachedJson);
        return DashboardBiData.fromJson(data);
      }
    } catch (_) {}

    // Si no hay datos previos ni red, devolver estructura inicial limpia
    return DashboardBiData(
      diasAnalizados: dias,
      totalVentas: 0.0,
      totalCostos: 0.0,
      margenBrutoSoles: 0.0,
      porcentajeMargenBruto: 0.0,
      ticketPromedioHoy: 0.0,
      ticketPromedioSemanal: 0.0,
      ticketPromedioPeriodo: 0.0,
      cantidadVentasHoy: 0,
      cantidadVentasPeriodo: 0,
      productosEstrella: [],
      productosHueso: [],
      totalCapitalInmovilizado: 0.0,
      totalProductosHueso: 0,
      distribucionHoraria: List.generate(
        24,
        (h) => HorarioPico(
          hora: h,
          etiquetaHora: '${h.toString().padLeft(2, '0')}:00 - ${((h + 1) % 24).toString().padLeft(2, '0')}:00',
          cantidadTickets: 0,
          totalVentas: 0.0,
          esPico: false,
        ),
      ),
      horaPicoMaxima: 'Sin datos aún',
      horaValleMinima: 'Sin datos aún',
      recomendacionTurnos: 'Registra ventas con tus productos para calcular los picos de afluencia.',
    );
  }

  /// Exporta el informe analítico a formato CSV descargable o copiable al portapapeles
  Future<bool> exportarInformeCsv(DashboardBiData data) async {
    final csvString = CsvExporter.generarCsvDashboardBi(data);
    final fileName = 'reporte_bi_cajaya_${data.diasAnalizados}d_${DateTime.now().millisecondsSinceEpoch}.csv';
    return await CsvExporter.descargarOCompartirCsv(
      nombreArchivo: fileName,
      contenidoCsv: csvString,
    );
  }
}
