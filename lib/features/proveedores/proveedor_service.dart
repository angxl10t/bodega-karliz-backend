import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/api_client.dart';
import 'proveedor_model.dart';

class ProveedorService {
  final ApiClient _apiClient = ApiClient();

  static List<Proveedor>? _cachedProveedores;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(seconds: 60);

  /// Notificador reactivo para que la pantalla de Compras y selección de proveedores
  /// sincronice instantáneamente cuando se agregue o modifique un proveedor.
  static final ValueNotifier<int> proveedoresRevision = ValueNotifier<int>(0);

  static void invalidateCache() {
    _cachedProveedores = null;
    _cacheTimestamp = null;
    proveedoresRevision.value++;
  }

  Future<List<Proveedor>> getProveedores({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedProveedores != null && _cacheTimestamp != null) {
      if (DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
        return List<Proveedor>.from(_cachedProveedores!);
      }
    }

    try {
      final response = await _apiClient.get('/proveedores');
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        final provs = jsonList.map((json) => Proveedor.fromJson(json)).toList();
        _cachedProveedores = provs;
        _cacheTimestamp = DateTime.now();
        return List<Proveedor>.from(provs);
      }
      return _cachedProveedores != null ? List<Proveedor>.from(_cachedProveedores!) : [];
    } catch (e) {
      return _cachedProveedores != null ? List<Proveedor>.from(_cachedProveedores!) : [];
    }
  }

  Future<({bool ok, String? error, Proveedor? proveedor})> crearProveedorConDetalle(Proveedor proveedor) async {
    try {
      final response = await _apiClient.post('/proveedores', proveedor.toJson());
      if (response.statusCode == 201 || response.statusCode == 200) {
        invalidateCache();
        Proveedor? creado;
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data is Map<String, dynamic>) {
            creado = Proveedor.fromJson(data);
          }
        } catch (_) {}
        return (ok: true, error: null, proveedor: creado);
      }
      try {
        final err = jsonDecode(utf8.decode(response.bodyBytes));
        if (err is Map && err.containsKey('error')) {
          return (ok: false, error: err['error'].toString(), proveedor: null);
        }
      } catch (_) {}
      return (ok: false, error: 'Error ${response.statusCode} al registrar el proveedor.', proveedor: null);
    } catch (e) {
      return (ok: false, error: 'Error de conexión al registrar proveedor.', proveedor: null);
    }
  }

  Future<bool> crearProveedor(Proveedor proveedor) async {
    final res = await crearProveedorConDetalle(proveedor);
    return res.ok;
  }

  Future<bool> desactivarProveedor(int id) async {
    try {
      final response = await _apiClient.delete('/proveedores/$id');
      final ok = response.statusCode == 204 || response.statusCode == 200;
      if (ok) invalidateCache();
      return ok;
    } catch (e) {
      return false;
    }
  }
}
