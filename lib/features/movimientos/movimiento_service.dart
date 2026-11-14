import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../productos/producto_service.dart';
import 'movimiento_model.dart';

class MovimientoService {
  final ApiClient _apiClient = ApiClient();

  static List<MovimientoInventario>? _mockMovimientos;

  @visibleForTesting
  static void setMockMovimientos(List<MovimientoInventario>? mock) {
    _mockMovimientos = mock != null
        ? List<MovimientoInventario>.from(mock)
        : null;
  }

  Future<List<MovimientoInventario>> getMovimientos() async {
    if (_mockMovimientos != null) {
      return List<MovimientoInventario>.from(_mockMovimientos!);
    }
    try {
      final response = await _apiClient.get('/movimientos');
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        return jsonList
            .map((json) => MovimientoInventario.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<MovimientoInventario>> getMovimientosPorProducto(
    int idProducto,
  ) async {
    try {
      final response = await _apiClient.get(
        '/movimientos/producto/$idProducto',
      );
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        return jsonList
            .map((json) => MovimientoInventario.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> registrarAjuste({
    required int idProducto,
    required double cantidad,
    required String tipoAjuste,
    required String motivo,
  }) async {
    try {
      final response = await _apiClient.post('/movimientos/ajuste', {
        'idProducto': idProducto,
        'cantidad': cantidad,
        'tipoAjuste': tipoAjuste,
        'motivo': motivo,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        ProductoService.invalidateCache();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
