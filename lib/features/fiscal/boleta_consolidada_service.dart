import 'dart:convert';

import '../../core/api_client.dart';

class ResumenVentasMenores {
  final DateTime fecha;
  final bool yaRegistrada;
  final int? idBoletaConsolidada;
  final String? serieCorrelativo;
  final String? tipoEmision;
  final double? montoRegistrado;
  final int? cantidadOperacionesRegistradas;
  final String? observaciones;
  final String? usuarioRegistro;
  final DateTime? fechaRegistro;
  final double montoSugerido;
  final int cantidadOperacionesSugeridas;
  final String? baseLegal;

  ResumenVentasMenores({
    required this.fecha,
    required this.yaRegistrada,
    this.idBoletaConsolidada,
    this.serieCorrelativo,
    this.tipoEmision,
    this.montoRegistrado,
    this.cantidadOperacionesRegistradas,
    this.observaciones,
    this.usuarioRegistro,
    this.fechaRegistro,
    required this.montoSugerido,
    required this.cantidadOperacionesSugeridas,
    this.baseLegal,
  });

  factory ResumenVentasMenores.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is String) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return ResumenVentasMenores(
      fecha: parseDate(json['fecha']),
      yaRegistrada: json['yaRegistrada'] == true,
      idBoletaConsolidada: json['idBoletaConsolidada'] is num
          ? (json['idBoletaConsolidada'] as num).toInt()
          : null,
      serieCorrelativo: json['serieCorrelativo'],
      tipoEmision: json['tipoEmision'],
      montoRegistrado: json['montoRegistrado'] is num
          ? (json['montoRegistrado'] as num).toDouble()
          : null,
      cantidadOperacionesRegistradas:
          json['cantidadOperacionesRegistradas'] is num
          ? (json['cantidadOperacionesRegistradas'] as num).toInt()
          : null,
      observaciones: json['observaciones'],
      usuarioRegistro: json['usuarioRegistro'],
      fechaRegistro: json['fechaRegistro'] != null
          ? DateTime.tryParse(json['fechaRegistro'].toString())
          : null,
      montoSugerido: (json['montoSugerido'] as num?)?.toDouble() ?? 0.0,
      cantidadOperacionesSugeridas:
          (json['cantidadOperacionesSugeridas'] as num?)?.toInt() ?? 0,
      baseLegal: json['baseLegal'],
    );
  }
}

class BoletaConsolidadaRecord {
  final int? idBoletaConsolidada;
  final DateTime fechaEmision;
  final double montoTotal;
  final int cantidadOperaciones;
  final String serieCorrelativo;
  final String tipoEmision;
  final String? observaciones;
  final String? usuarioRegistro;
  final DateTime? fechaRegistro;

  BoletaConsolidadaRecord({
    this.idBoletaConsolidada,
    required this.fechaEmision,
    required this.montoTotal,
    required this.cantidadOperaciones,
    required this.serieCorrelativo,
    this.tipoEmision = 'TALONARIO_FISICO',
    this.observaciones,
    this.usuarioRegistro,
    this.fechaRegistro,
  });

  factory BoletaConsolidadaRecord.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is String) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return BoletaConsolidadaRecord(
      idBoletaConsolidada: json['idBoletaConsolidada'] is num
          ? (json['idBoletaConsolidada'] as num).toInt()
          : null,
      fechaEmision: parseDate(json['fechaEmision']),
      montoTotal: (json['montoTotal'] as num?)?.toDouble() ?? 0.0,
      cantidadOperaciones: (json['cantidadOperaciones'] as num?)?.toInt() ?? 1,
      serieCorrelativo: json['serieCorrelativo'] ?? '001-000001',
      tipoEmision: json['tipoEmision'] ?? 'TALONARIO_FISICO',
      observaciones: json['observaciones'],
      usuarioRegistro: json['usuarioRegistro'],
      fechaRegistro: json['fechaRegistro'] != null
          ? DateTime.tryParse(json['fechaRegistro'].toString())
          : null,
    );
  }
}

class BoletaConsolidadaService {
  final ApiClient _client;

  BoletaConsolidadaService({ApiClient? client})
    : _client = client ?? ApiClient();

  /// Obtiene la sugerencia de cálculo para una fecha dada (por defecto hoy)
  Future<ResumenVentasMenores> obtenerSugerencia({DateTime? fecha}) async {
    final f = fecha ?? DateTime.now();
    final fechaIso =
        '${f.year.toString().padLeft(4, '0')}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';
    final response = await _client.get(
      '/bodegas/fiscal/boleta-consolidada/sugerencia?fecha=$fechaIso',
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return ResumenVentasMenores.fromJson(data);
    }

    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo obtener el resumen de ventas menores a S/ 5.00',
    );
    throw Exception(errorMsg);
  }

  /// Registra manualmente o actualiza la Boleta Consolidada Diaria
  Future<BoletaConsolidadaRecord> registrarBoletaConsolidada({
    required DateTime fecha,
    required double montoTotal,
    required int cantidadOperaciones,
    required String serieCorrelativo,
    String tipoEmision = 'TALONARIO_FISICO',
    String? observaciones,
  }) async {
    final fechaIso =
        '${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

    final body = <String, dynamic>{
      'fecha': fechaIso,
      'montoTotal': montoTotal,
      'cantidadOperaciones': cantidadOperaciones,
      'serieCorrelativo': serieCorrelativo.trim().toUpperCase(),
      'tipoEmision': tipoEmision,
      'observaciones': observaciones?.trim(),
    };

    final response = await _client.post(
      '/bodegas/fiscal/boleta-consolidada',
      body,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return BoletaConsolidadaRecord.fromJson(data);
    }

    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo registrar la boleta consolidada diaria',
    );
    throw Exception(errorMsg);
  }

  /// Obtiene el historial de boletas consolidadas registradas
  Future<List<BoletaConsolidadaRecord>> listarHistorial({
    int limit = 30,
  }) async {
    final response = await _client.get(
      '/bodegas/fiscal/boleta-consolidada/historial?limit=$limit',
    );

    if (response.statusCode == 200) {
      final List list = jsonDecode(utf8.decode(response.bodyBytes));
      return list
          .map((item) => BoletaConsolidadaRecord.fromJson(item))
          .toList();
    }

    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo obtener el historial de boletas consolidadas',
    );
    throw Exception(errorMsg);
  }
}
