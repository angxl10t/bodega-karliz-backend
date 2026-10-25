import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/api_client.dart';
import '../../core/offline/offline_catalog_service.dart';
import '../../core/offline/offline_sync_manager.dart';
import 'producto_model.dart';

class ProductoService {
  final ApiClient _apiClient = ApiClient();

  static List<Producto>? _cachedProductos;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(seconds: 45);

  /// Notificador reactivo para que todas las pantallas (Ventas, Compras, Dashboard, Catálogo)
  /// sincronicen sus listas de inmediato cuando se cree, edite, venda o elimine un producto.
  static final ValueNotifier<int> productosRevision = ValueNotifier<int>(0);

  /// Invalida manualmente la caché en memoria (ej: tras crear, editar, vender o comprar)
  static void invalidateCache() {
    _cachedProductos = null;
    _cacheTimestamp = null;
    productosRevision.value++;
  }

  /// Permite inyectar productos en tests sin realizar llamadas de red HTTP
  @visibleForTesting
  static void setMockProductos(List<Producto> productos) {
    _cachedProductos = List<Producto>.from(productos);
    _cacheTimestamp = DateTime.now();
  }

  /// Lista los productos disponibles. Si hay una copia en memoria reciente (< 45s) y no se
  /// solicita forceRefresh, la retorna de forma instantánea sin demora de red.
  /// Si el backend no responde o no hay internet, recurre automáticamente al catálogo
  /// persistente local de contingencia (Local-First).
  Future<List<Producto>> getProductos({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedProductos != null && _cacheTimestamp != null) {
      if (DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
        return List<Producto>.from(_cachedProductos!);
      }
    }

    try {
      final response = await _apiClient.get('/productos');
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        final prods = jsonList.map((json) => Producto.fromJson(json)).toList();
        _cachedProductos = prods;
        _cacheTimestamp = DateTime.now();

        // Almacenar en caché local persistente para contingencias offline
        OfflineCatalogService().saveCatalog(prods);
        OfflineSyncManager.instance.isOfflineNotifier.value = false;

        return List<Producto>.from(prods);
      }

      // Fallback resiliente al catálogo local
      final localProds = await OfflineCatalogService().getCachedCatalog();
      if (localProds.isNotEmpty) {
        _cachedProductos = localProds;
        OfflineSyncManager.instance.isOfflineNotifier.value = true;
        return List<Producto>.from(localProds);
      }
      return _cachedProductos != null ? List<Producto>.from(_cachedProductos!) : [];
    } catch (e) {
      // Fallback resiliente ante cortes de red o caídas de servidor
      final localProds = await OfflineCatalogService().getCachedCatalog();
      if (localProds.isNotEmpty) {
        _cachedProductos = localProds;
        OfflineSyncManager.instance.isOfflineNotifier.value = true;
        return List<Producto>.from(localProds);
      }
      return _cachedProductos != null ? List<Producto>.from(_cachedProductos!) : [];
    }
  }

  Future<({bool ok, String? error, Producto? producto})> crearProductoConDetalle(Producto producto) async {
    try {
      final response = await _apiClient.post('/productos', producto.toJson());
      if (response.statusCode == 201 || response.statusCode == 200) {
        invalidateCache();
        Producto? creado;
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data is Map<String, dynamic>) {
            creado = Producto.fromJson(data);
          }
        } catch (_) {}
        return (ok: true, error: null, producto: creado);
      }
      final errorMsg = ApiClient.extractErrorMessage(response, 'Error al registrar el producto');
      return (ok: false, error: errorMsg, producto: null);
    } catch (e) {
      return (ok: false, error: 'Error de conexión', producto: null);
    }
  }

  Future<bool> crearProducto(Producto producto) async {
    final res = await crearProductoConDetalle(producto);
    return res.ok;
  }

  Future<({bool ok, String? error})> actualizarProductoConDetalle(Producto producto) async {
    if (producto.idProducto == null) return (ok: false, error: 'ID de producto nulo');
    try {
      final response = await _apiClient.put(
        '/productos/${producto.idProducto}',
        producto.toJson(includeStock: false),
      );
      if (response.statusCode == 200) {
        invalidateCache();
        return (ok: true, error: null);
      }
      final errorMsg = ApiClient.extractErrorMessage(response, 'Error al actualizar el producto');
      return (ok: false, error: errorMsg);
    } catch (e) {
      return (ok: false, error: 'Error de conexión');
    }
  }

  Future<bool> actualizarProducto(Producto producto) async {
    final res = await actualizarProductoConDetalle(producto);
    return res.ok;
  }

  Future<bool> desactivarProducto(int idProducto) async {
    try {
      final response = await _apiClient.delete('/productos/$idProducto');
      final ok = response.statusCode == 204 || response.statusCode == 200;
      if (ok) invalidateCache();
      return ok;
    } catch (e) {
      return false;
    }
  }
}
