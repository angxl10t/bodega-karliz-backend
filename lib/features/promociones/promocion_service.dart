import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import 'promocion_model.dart';

class PromocionService {
  final ApiClient _apiClient;

  PromocionService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  @visibleForTesting
  static List<Promocion>? mockPromociones;
  @visibleForTesting
  static List<SugerenciaComboHueso>? mockSugerencias;

  @visibleForTesting
  static void setMockData({
    List<Promocion>? promociones,
    List<SugerenciaComboHueso>? sugerencias,
  }) {
    mockPromociones = promociones != null ? List.from(promociones) : null;
    mockSugerencias = sugerencias != null ? List.from(sugerencias) : null;
  }

  Future<List<Promocion>> obtenerPromociones() async {
    if (mockPromociones != null) {
      return List.from(mockPromociones!);
    }
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
    if (mockSugerencias != null) {
      return List.from(mockSugerencias!);
    }
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
    if (mockPromociones != null) {
      final nueva = Promocion.fromJson({
        ...data,
        'idPromocion': (mockPromociones!.length + 1),
      });
      mockPromociones!.add(nueva);
      return nueva;
    }
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
    if (mockPromociones != null) {
      final idx = mockPromociones!.indexWhere((p) => p.idPromocion == id);
      final actualizada = Promocion.fromJson({...data, 'idPromocion': id});
      if (idx != -1) {
        mockPromociones![idx] = actualizada;
      } else {
        mockPromociones!.add(actualizada);
      }
      return actualizada;
    }
    final response = await _apiClient.put('/promociones/$id', data);
    if (response.statusCode == 200) {
      return Promocion.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      final err = ApiClient.extractErrorMessage(response);
      throw Exception(err.isNotEmpty ? err : 'Error al actualizar promoción');
    }
  }

  Future<bool> cambiarEstado(int id, bool activo) async {
    if (mockPromociones != null) {
      final idx = mockPromociones!.indexWhere((p) => p.idPromocion == id);
      if (idx != -1) {
        final p = mockPromociones![idx];
        mockPromociones![idx] = Promocion(
          idPromocion: p.idPromocion,
          idBodega: p.idBodega,
          titulo: p.titulo,
          descripcion: p.descripcion,
          tipoPromocion: p.tipoPromocion,
          alcance: p.alcance,
          valorDescuento: p.valorDescuento,
          categoriaObjetivo: p.categoriaObjetivo,
          marcaObjetivo: p.marcaObjetivo,
          idProductoPrincipal: p.idProductoPrincipal,
          nombreProductoPrincipal: p.nombreProductoPrincipal,
          idProductoSecundario: p.idProductoSecundario,
          nombreProductoSecundario: p.nombreProductoSecundario,
          precioCombo: p.precioCombo,
          badgeTexto: p.badgeTexto,
          colorBadge: p.colorBadge,
          fechaInicio: p.fechaInicio,
          fechaFin: p.fechaFin,
          activo: activo,
          esSugerenciaHueso: p.esSugerenciaHueso,
        );
      }
      return true;
    }
    final response = await _apiClient.patch('/promociones/$id/estado', {
      'activo': activo,
    });
    return response.statusCode == 200;
  }

  Future<bool> eliminarPromocion(int id) async {
    if (mockPromociones != null) {
      mockPromociones!.removeWhere((p) => p.idPromocion == id);
      return true;
    }
    final response = await _apiClient.delete('/promociones/$id');
    return response.statusCode == 200;
  }
}
