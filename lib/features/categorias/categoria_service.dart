import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../../core/secure_storage_service.dart';
import 'categoria_model.dart';

class CategoriaService {
  final ApiClient _apiClient;

  CategoriaService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient() {
    _ensureCleanupRegistered();
  }

  static bool _cleanupRegistered = false;
  static void _ensureCleanupRegistered() {
    if (_cleanupRegistered) return;
    _cleanupRegistered = true;
    SecureStorageService.registerSessionCleanup(
      () => invalidateCache(notify: false),
    );
  }

  static List<Categoria>? _cachedCategorias;
  static DateTime? _cacheTimestamp;
  static Future<List<Categoria>>? _inFlightCategorias;
  static int _cacheEpoch = 0;
  static const Duration _cacheDuration = Duration(seconds: 60);

  /// Notificador reactivo para que todas las vistas (Catálogo, POS, Filtros)
  /// sincronicen sus listas cuando se agregue o actualice una categoría.
  static final ValueNotifier<int> categoriasRevision = ValueNotifier<int>(0);

  static void invalidateCache({bool notify = true}) {
    _cachedCategorias = null;
    _cacheTimestamp = null;
    _inFlightCategorias = null;
    _cacheEpoch++;
    if (notify) {
      categoriasRevision.value++;
    }
  }

  /// Permite inyectar categorías en tests sin realizar llamadas HTTP de red
  @visibleForTesting
  static void setMockCategorias(List<Categoria> categorias) {
    _cachedCategorias = List<Categoria>.from(categorias);
    _cacheTimestamp = DateTime.now();
    _inFlightCategorias = null;
    _cacheEpoch++;
  }

  Future<List<Categoria>> getCategorias({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCategorias != null && _cacheTimestamp != null) {
      if (DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
        return List<Categoria>.from(_cachedCategorias!);
      }
    }

    if (!forceRefresh && _inFlightCategorias != null) {
      return List<Categoria>.from(await _inFlightCategorias!);
    }

    final epoch = _cacheEpoch;
    final future = _fetchCategoriasFromNetwork(epoch);
    _inFlightCategorias = future;
    try {
      final result = await future;
      return List<Categoria>.from(result);
    } finally {
      if (identical(_inFlightCategorias, future)) {
        _inFlightCategorias = null;
      }
    }
  }

  Future<List<Categoria>> _fetchCategoriasFromNetwork(int epoch) async {
    try {
      final response = await _apiClient.get('/categorias');
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        final cats = jsonList.map((json) => Categoria.fromJson(json)).toList();
        if (epoch == _cacheEpoch) {
          _cachedCategorias = cats;
          _cacheTimestamp = DateTime.now();
        }
        return cats;
      }
      return _cachedCategorias != null
          ? List<Categoria>.from(_cachedCategorias!)
          : [];
    } catch (e) {
      return _cachedCategorias != null
          ? List<Categoria>.from(_cachedCategorias!)
          : [];
    }
  }

  Future<Categoria?> crearCategoria(
    String nombre, [
    String? descripcion,
  ]) async {
    try {
      final response = await _apiClient.post('/categorias', {
        'nombre': nombre,
        'descripcion': descripcion ?? 'Categoría de productos',
        'estado': true,
      });
      if (response.statusCode == 201 || response.statusCode == 200) {
        invalidateCache();
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return Categoria.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
