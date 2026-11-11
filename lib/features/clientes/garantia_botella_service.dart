import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../../core/secure_storage_service.dart';
import 'garantia_botella_model.dart';

class GarantiaBotellaService {
  final ApiClient _apiClient;

  GarantiaBotellaService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient() {
    _ensureCleanupRegistered();
  }

  static bool _cleanupRegistered = false;
  static void _ensureCleanupRegistered() {
    if (_cleanupRegistered) return;
    _cleanupRegistered = true;
    SecureStorageService.registerSessionCleanup(invalidateCache);
  }

  static List<GarantiaBotella>? _cachedGarantias;
  static DateTime? _cacheTimestamp;
  static Future<List<GarantiaBotella>>? _inFlightGarantias;
  static int _cacheEpoch = 0;
  static const Duration _cacheDuration = Duration(seconds: 45);

  static final ValueNotifier<int> garantiasRevision = ValueNotifier<int>(0);

  static void invalidateCache() {
    _cachedGarantias = null;
    _cacheTimestamp = null;
    _inFlightGarantias = null;
    _cacheEpoch++;
    garantiasRevision.value++;
  }

  Future<List<GarantiaBotella>> getGarantias({
    String? estado,
    String? query,
    bool forceRefresh = false,
  }) async {
    final hasFilter =
        (query != null && query.trim().isNotEmpty) ||
        (estado != null && estado.trim().isNotEmpty && estado != 'TODAS');

    if (!forceRefresh &&
        !hasFilter &&
        _cachedGarantias != null &&
        _cacheTimestamp != null) {
      if (DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
        return List<GarantiaBotella>.from(_cachedGarantias!);
      }
    }

    if (!forceRefresh && !hasFilter && _inFlightGarantias != null) {
      return List<GarantiaBotella>.from(await _inFlightGarantias!);
    }

    final queryParams = <String>[];
    if (estado != null && estado.trim().isNotEmpty && estado != 'TODAS') {
      queryParams.add('estado=${Uri.encodeComponent(estado.trim())}');
    }
    if (query != null && query.trim().isNotEmpty) {
      queryParams.add('query=${Uri.encodeComponent(query.trim())}');
    }

    final endpoint = queryParams.isEmpty
        ? '/garantias-botellas'
        : '/garantias-botellas?${queryParams.join('&')}';

    final epoch = _cacheEpoch;
    final future = _fetchGarantiasFromNetwork(endpoint, hasFilter, epoch);
    if (!hasFilter) {
      _inFlightGarantias = future;
    }
    try {
      final result = await future;
      return List<GarantiaBotella>.from(result);
    } finally {
      if (!hasFilter && identical(_inFlightGarantias, future)) {
        _inFlightGarantias = null;
      }
    }
  }

  Future<List<GarantiaBotella>> _fetchGarantiasFromNetwork(
    String endpoint,
    bool hasFilter,
    int epoch,
  ) async {
    try {
      final response = await _apiClient.get(endpoint);

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        final items = list
            .map((j) => GarantiaBotella.fromJson(j as Map<String, dynamic>))
            .toList();

        if (!hasFilter && epoch == _cacheEpoch) {
          _cachedGarantias = items;
          _cacheTimestamp = DateTime.now();
        }
        return items;
      }
      return (!hasFilter && _cachedGarantias != null)
          ? List<GarantiaBotella>.from(_cachedGarantias!)
          : [];
    } catch (e) {
      debugPrint('Error en getGarantias: $e');
      return (!hasFilter && _cachedGarantias != null)
          ? List<GarantiaBotella>.from(_cachedGarantias!)
          : [];
    }
  }

  Future<ResumenGarantias?> getResumenGarantias() async {
    try {
      final response = await _apiClient.get('/garantias-botellas/resumen');
      if (response.statusCode == 200) {
        final map =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return ResumenGarantias.fromJson(map);
      }
      return null;
    } catch (e) {
      debugPrint('Error en getResumenGarantias: $e');
      return null;
    }
  }

  Future<GarantiaBotella> crearGarantia(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/garantias-botellas', data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      invalidateCache();
      return GarantiaBotella.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)),
      );
    }
    final msg = ApiClient.extractErrorMessage(
      response,
      'No se pudo registrar la garantía de botellas',
    );
    throw Exception(msg);
  }

  Future<GarantiaBotella> devolverGarantia(
    int idGarantia, {
    int? cantidadDevolver,
    double? montoEntregado,
    String? notas,
  }) async {
    final body = <String, dynamic>{};
    if (cantidadDevolver != null && cantidadDevolver > 0) {
      body['cantidadDevolver'] = cantidadDevolver;
    }
    if (montoEntregado != null && montoEntregado > 0) {
      body['montoEntregado'] = montoEntregado;
    }
    if (notas != null && notas.trim().isNotEmpty) {
      body['notas'] = notas.trim();
    }

    final response = await _apiClient.post(
      '/garantias-botellas/$idGarantia/devolver',
      body,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      invalidateCache();
      return GarantiaBotella.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)),
      );
    }
    final msg = ApiClient.extractErrorMessage(
      response,
      'No se pudo registrar la devolución de botellas',
    );
    throw Exception(msg);
  }

  Future<void> eliminarGarantia(int idGarantia) async {
    final response = await _apiClient.delete('/garantias-botellas/$idGarantia');
    if (response.statusCode == 200 || response.statusCode == 204) {
      invalidateCache();
      return;
    }
    final msg = ApiClient.extractErrorMessage(
      response,
      'No se pudo eliminar la garantía',
    );
    throw Exception(msg);
  }
}
