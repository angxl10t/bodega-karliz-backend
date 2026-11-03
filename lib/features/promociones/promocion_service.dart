import 'dart:convert';

import '../../core/api_client.dart';
import 'promocion_model.dart';

class PromocionService {
  final ApiClient _apiClient;

  PromocionService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<List<Promocion>> obtenerPromociones() async {
    final response = await _apiClient.get('/promociones');
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
      return list
          .map((item) => Promocion.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Error al cargar promociones: ${response.statusCode}');
    }
  }

  Future<List<SugerenciaComboHueso>> obtenerSugerenciasHuesos() async {
    final response = await _apiClient.get('/promociones/sugerencias-hueso');
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
      return list
          .map(
            (item) =>
                SugerenciaComboHueso.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } else {
      throw Exception(
        'Error al cargar sugerencias de combos: ${response.statusCode}',
      );
    }
  }

  Future<Promocion> crearPromocion(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/promociones', data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Promocion.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      final err = ApiClient.extractErrorMessage(response);
      throw Exception(err.isNotEmpty ? err : 'Error al crear promoción');
    }
  }

  Future<Promocion> actualizarPromocion(
    int id,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.put('/promociones/$id', data);
    if (response.statusCode == 200) {
      return Promocion.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      final err = ApiClient.extractErrorMessage(response);
      throw Exception(err.isNotEmpty ? err : 'Error al actualizar promoción');
    }
  }

  Future<bool> cambiarEstado(int id, bool activo) async {
    final response = await _apiClient.patch('/promociones/$id/estado', {
      'activo': activo,
    });
    return response.statusCode == 200;
  }

  Future<bool> eliminarPromocion(int id) async {
    final response = await _apiClient.delete('/promociones/$id');
    return response.statusCode == 200;
  }
}
