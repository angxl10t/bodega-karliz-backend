import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/productos/producto_model.dart';
import '../../features/productos/producto_service.dart';
import '../secure_storage_service.dart';

/// Servicio de almacenamiento local resiliente (Local-First) para el catálogo de productos.
/// Permite que el POS funcione al 100% incluso ante cortes totales de red o fallas en el backend.
class OfflineCatalogService {
  static final OfflineCatalogService _instance = OfflineCatalogService._internal();
  factory OfflineCatalogService() => _instance;
  OfflineCatalogService._internal();

  static const String _keyPrefixCatalog = 'cajaya_offline_catalog_';
  static const String _keyPrefixTs = 'cajaya_offline_catalog_ts_';

  List<Producto>? _inMemoryCatalog;
  DateTime? _lastSyncDate;

  /// Obtiene el identificador de bodega activo para aislar el catálogo multi-inquilino
  Future<String> _getTenantId(String? overrideId) async {
    if (overrideId != null && overrideId.isNotEmpty) return overrideId;
    final id = await SecureStorageService.read('id_bodega');
    return id ?? 'default_tenant';
  }

  /// Guarda el catálogo completo de productos en el almacenamiento local persistente (SharedPreferences / IndexedDB)
  Future<void> saveCatalog(List<Producto> productos, {String? idBodega}) async {
    if (productos.isEmpty) return;
    try {
      final tenant = await _getTenantId(idBodega);
      final prefs = await SharedPreferences.getInstance();

      final jsonList = productos.map((p) => p.toJson()).toList();
      final jsonString = jsonEncode(jsonList);

      final now = DateTime.now();
      await prefs.setString('$_keyPrefixCatalog$tenant', jsonString);
      await prefs.setString('$_keyPrefixTs$tenant', now.toIso8601String());

      _inMemoryCatalog = List<Producto>.from(productos);
      _lastSyncDate = now;
      debugPrint('[OfflineCatalog] Catálogo guardado en caché local: ${productos.length} productos (Bodega $tenant)');
    } catch (e) {
      debugPrint('[OfflineCatalog] Error guardando catálogo en caché local: $e');
    }
  }

  /// Recupera el catálogo guardado localmente en caso de que el backend no responda o no haya internet
  Future<List<Producto>> getCachedCatalog({String? idBodega}) async {
    if (_inMemoryCatalog != null && _inMemoryCatalog!.isNotEmpty) {
      return List<Producto>.from(_inMemoryCatalog!);
    }

    try {
      final tenant = await _getTenantId(idBodega);
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefixCatalog$tenant';

      if (!prefs.containsKey(key)) {
        debugPrint('[OfflineCatalog] No hay catálogo local para la bodega $tenant');
        return [];
      }

      final jsonString = prefs.getString(key);
      if (jsonString == null || jsonString.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(jsonString);
      final productos = decoded.map((j) => Producto.fromJson(j as Map<String, dynamic>)).toList();

      _inMemoryCatalog = productos;

      final tsString = prefs.getString('$_keyPrefixTs$tenant');
      if (tsString != null) {
        _lastSyncDate = DateTime.tryParse(tsString);
      }

      debugPrint('[OfflineCatalog] Recuperados ${productos.length} productos desde almacenamiento local');
      return List<Producto>.from(productos);
    } catch (e) {
      debugPrint('[OfflineCatalog] Error leyendo catálogo local: $e');
      return [];
    }
  }

  /// Descuenta de inmediato el stock en el catálogo local al completarse una venta offline.
  /// Esto previene sobreventas accidentales mientras el cajero sigue atendiendo sin conexión.
  Future<void> deductStockLocally(int idProducto, double cantidadVendida, {String? idBodega}) async {
    final catalog = await getCachedCatalog(idBodega: idBodega);
    if (catalog.isEmpty) return;

    bool modificado = false;
    final updatedList = catalog.map((p) {
      if (p.idProducto == idProducto) {
        modificado = true;
        final nuevoStock = (p.stockActual - cantidadVendida).clamp(0.0, 999999.0);
        return p.copyWith(stockActual: nuevoStock);
      }
      return p;
    }).toList();

    if (modificado) {
      _inMemoryCatalog = updatedList;
      await saveCatalog(updatedList, idBodega: idBodega);
      // Notifica a las pantallas para que actualicen sus vistas al instante
      ProductoService.productosRevision.value++;
    }
  }

  /// Retorna la fecha y hora de la última sincronización del catálogo
  Future<DateTime?> getLastSyncDate({String? idBodega}) async {
    if (_lastSyncDate != null) return _lastSyncDate;
    final tenant = await _getTenantId(idBodega);
    final prefs = await SharedPreferences.getInstance();
    final tsString = prefs.getString('$_keyPrefixTs$tenant');
    if (tsString != null) {
      _lastSyncDate = DateTime.tryParse(tsString);
    }
    return _lastSyncDate;
  }

  /// Limpia la memoria caché local (ej: al cerrar sesión)
  void clearMemoryCache() {
    _inMemoryCatalog = null;
    _lastSyncDate = null;
  }
}
