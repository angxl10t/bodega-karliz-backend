import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../../core/marca_detector_service.dart';
import '../../core/offline/offline_catalog_service.dart';
import '../../core/offline/offline_sync_manager.dart';
import 'producto_model.dart';

class ProductoService {
  final ApiClient _apiClient;

  ProductoService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  static List<Producto>? _cachedProductos;
  static DateTime? _cacheTimestamp;
  static Future<List<Producto>>? _inFlightProductos;
  static int _cacheEpoch = 0;
  static const Duration _cacheDuration = Duration(seconds: 45);

  /// Notificador reactivo para que todas las pantallas (Ventas, Compras, Dashboard, Catálogo)
  /// sincronicen sus listas de inmediato cuando se cree, edite, venda o elimine un producto.
  static final ValueNotifier<int> productosRevision = ValueNotifier<int>(0);

  /// Invalida manualmente la caché en memoria (ej: tras crear, editar, vender o comprar)
  static void invalidateCache() {
    _cachedProductos = null;
    _cacheTimestamp = null;
    _inFlightProductos = null;
    _cacheEpoch++;
    productosRevision.value++;
  }

  /// Permite inyectar productos en tests sin realizar llamadas de red HTTP
  @visibleForTesting
  static void setMockProductos(List<Producto> productos) {
    _cachedProductos = List<Producto>.from(productos);
    _cacheTimestamp = DateTime.now();
    _inFlightProductos = null;
    _cacheEpoch++;
  }

  /// Lista los productos disponibles. Si hay una copia en memoria reciente (< 45s) y no se
  /// solicita forceRefresh, la retorna de forma instantánea sin demora de red.
  /// Coalesce llamadas concurrentes cuando la caché está fría para evitar peticiones HTTP duplicadas.
  /// Si el backend no responde o no hay internet, recurre automáticamente al catálogo
  /// persistente local de contingencia (Local-First).
  Future<List<Producto>> getProductos({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedProductos != null && _cacheTimestamp != null) {
      if (DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
        return List<Producto>.from(_cachedProductos!);
      }
    }

    if (!forceRefresh && _inFlightProductos != null) {
      return List<Producto>.from(await _inFlightProductos!);
    }

    final epoch = _cacheEpoch;
    final future = _fetchProductosFromNetwork(epoch);
    _inFlightProductos = future;
    try {
      final result = await future;
      return List<Producto>.from(result);
    } finally {
      if (identical(_inFlightProductos, future)) {
        _inFlightProductos = null;
      }
    }
  }

  Future<List<Producto>> _fetchProductosFromNetwork(int epoch) async {
    try {
      final response = await _apiClient.get('/productos');
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        final prods = jsonList.map((json) => Producto.fromJson(json)).toList();
        if (epoch == _cacheEpoch) {
          _cachedProductos = prods;
          _cacheTimestamp = DateTime.now();

          // Almacenar en caché local persistente para contingencias offline
          OfflineCatalogService().saveCatalog(prods);
          OfflineSyncManager.instance.isOfflineNotifier.value = false;
        }

        return prods;
      }

      // Fallback resiliente al catálogo local
      final localProds = await OfflineCatalogService().getCachedCatalog();
      if (localProds.isNotEmpty) {
        if (epoch == _cacheEpoch) {
          _cachedProductos = localProds;
          OfflineSyncManager.instance.isOfflineNotifier.value = true;
        }
        return localProds;
      }
      return _cachedProductos != null
          ? List<Producto>.from(_cachedProductos!)
          : [];
    } catch (e) {
      // Fallback resiliente ante cortes de red o caídas de servidor
      final localProds = await OfflineCatalogService().getCachedCatalog();
      if (localProds.isNotEmpty) {
        if (epoch == _cacheEpoch) {
          _cachedProductos = localProds;
          OfflineSyncManager.instance.isOfflineNotifier.value = true;
        }
        return localProds;
      }
      return _cachedProductos != null
          ? List<Producto>.from(_cachedProductos!)
          : [];
    }
  }

  Future<({bool ok, String? error, Producto? producto})>
  crearProductoConDetalle(Producto producto) async {
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
      final errorMsg = ApiClient.extractErrorMessage(
        response,
        'Error al registrar el producto',
      );
      return (ok: false, error: errorMsg, producto: null);
    } catch (e) {
      return (ok: false, error: 'Error de conexión', producto: null);
    }
  }

  Future<bool> crearProducto(Producto producto) async {
    final res = await crearProductoConDetalle(producto);
    return res.ok;
  }

  Future<({bool ok, String? error})> actualizarProductoConDetalle(
    Producto producto,
  ) async {
    if (producto.idProducto == null)
      return (ok: false, error: 'ID de producto nulo');
    try {
      final response = await _apiClient.put(
        '/productos/${producto.idProducto}',
        producto.toJson(includeStock: false),
      );
      if (response.statusCode == 200) {
        invalidateCache();
        return (ok: true, error: null);
      }
      final errorMsg = ApiClient.extractErrorMessage(
        response,
        'Error al actualizar el producto',
      );
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

  /// Obtiene la lista de marcas disponibles en el inventario de la bodega con su conteo de productos.
  /// Si el endpoint no responde o está offline, calcula las marcas automáticamente desde los productos locales.
  Future<List<MarcaInfo>> getMarcas() async {
    try {
      final response = await _apiClient.get('/productos/marcas');
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        return list
            .map((item) => MarcaInfo.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    // Fallback local: calcular a partir de los productos en caché/inventario
    final productos = await getProductos();
    final Map<String, int> conteo = {};
    for (final p in productos) {
      final m = p.marca?.trim();
      if (m != null && m.isNotEmpty) {
        conteo[m] = (conteo[m] ?? 0) + 1;
      }
    }
    final List<MarcaInfo> marcas = conteo.entries
        .map((e) => MarcaInfo(nombre: e.key, cantidadProductos: e.value))
        .toList();
    marcas.sort((a, b) {
      final cmp = b.cantidadProductos.compareTo(a.cantidadProductos);
      if (cmp != 0) return cmp;
      return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
    });
    return marcas;
  }
}
