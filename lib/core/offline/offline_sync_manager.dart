import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/productos/producto_service.dart';
import '../../features/ventas/venta_service.dart';
import '../api_client.dart';
import '../secure_storage_service.dart';
import 'offline_catalog_service.dart';
import 'offline_models.dart';

class SyncBatchResult {
  final int totalPendientes;
  final int sincronizadas;
  final int fallidas;
  final String? mensaje;

  SyncBatchResult({
    required this.totalPendientes,
    required this.sincronizadas,
    required this.fallidas,
    this.mensaje,
  });

  bool get todosExitosos => totalPendientes > 0 && fallidas == 0;
}

/// Gestor de sincronización en segundo plano (SyncManager) para el POS Offline-First.
/// Controla la cola de ventas desconectadas, garantiza la entrega atómica mediante
/// UUIDs de idempotencia y sincroniza con el servidor cuando la red está disponible.
class OfflineSyncManager {
  static final OfflineSyncManager _instance = OfflineSyncManager._internal();
  static OfflineSyncManager get instance => _instance;
  OfflineSyncManager._internal();

  final VentaService _ventaService = VentaService();
  final OfflineCatalogService _catalogService = OfflineCatalogService();
  final ApiClient _apiClient = ApiClient();

  static const String _keyPrefixQueue = 'cajaya_offline_sales_queue_';

  final List<OfflineVenta> _queue = [];
  bool _isInitialized = false;
  bool _isSyncing = false;
  Timer? _autoSyncTimer;

  // Notificadores reactivos para la UI
  final ValueNotifier<List<OfflineVenta>> pendingSalesNotifier = ValueNotifier<List<OfflineVenta>>([]);
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isOfflineNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<DateTime?> lastSyncSuccessNotifier = ValueNotifier<DateTime?>(null);

  int get pendingCount => _queue.length;
  double get pendingTotal => _queue.fold(0.0, (acc, v) => acc + v.total);

  /// Inicializa el SyncManager y carga la cola persistente desde disco
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await _loadQueue();
    startAutoSync();
  }

  Future<String> _getTenantId() async {
    final id = await SecureStorageService.read('id_bodega');
    return id ?? 'default_tenant';
  }

  /// Carga las ventas pendientes guardadas localmente
  Future<void> _loadQueue() async {
    try {
      final tenant = await _getTenantId();
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefixQueue$tenant';

      if (prefs.containsKey(key)) {
        final jsonString = prefs.getString(key);
        if (jsonString != null && jsonString.isNotEmpty) {
          final List<dynamic> list = jsonDecode(jsonString);
          _queue.clear();
          for (final item in list) {
            try {
              _queue.add(OfflineVenta.fromJson(item as Map<String, dynamic>));
            } catch (err) {
              debugPrint('[SyncManager] Error deserializando venta offline: $err');
            }
          }
        }
      }
      _notifyQueueChanged();
      debugPrint('[SyncManager] Cola offline inicializada: ${_queue.length} ventas pendientes (Bodega $tenant)');
    } catch (e) {
      debugPrint('[SyncManager] Error cargando cola offline: $e');
    }
  }

  /// Guarda la cola actualizada en el almacenamiento local persistente
  Future<void> _saveQueue() async {
    try {
      final tenant = await _getTenantId();
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefixQueue$tenant';

      final jsonList = _queue.map((v) => v.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
      _notifyQueueChanged();
    } catch (e) {
      debugPrint('[SyncManager] Error guardando cola offline: $e');
    }
  }

  void _notifyQueueChanged() {
    pendingSalesNotifier.value = List.unmodifiable(_queue);
  }

  /// Registra y firma una venta de forma local durante un corte de internet
  Future<OfflineVenta> enqueueSale(OfflineVenta venta) async {
    await init();
    _queue.add(venta);
    await _saveQueue();

    // Descuenta el stock localmente de inmediato para mantener consistencia en mostrador
    for (final det in venta.detalles) {
      await _catalogService.deductStockLocally(
        det.idProducto,
        det.cantidad,
        idBodega: venta.idBodega > 0 ? venta.idBodega.toString() : null,
      );
    }

    isOfflineNotifier.value = true;
    debugPrint('[SyncManager] Venta encolada offline: ${venta.localTicket} (UUID: ${venta.uuid}), Total: S/ ${venta.total.toStringAsFixed(2)}');

    // Intenta una sincronización inmediata en segundo plano
    syncPendingSales();

    return venta;
  }

  /// Comprueba rápidamente si el servidor backend está respondiendo
  Future<bool> checkServerReachable() async {
    try {
      final res = await _apiClient.get('/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Ejecuta la sincronización de todas las ventas pendientes en la cola
  Future<SyncBatchResult> syncPendingSales({bool isManual = false}) async {
    await init();

    if (_isSyncing) {
      return SyncBatchResult(
        totalPendientes: _queue.length,
        sincronizadas: 0,
        fallidas: 0,
        mensaje: 'Sincronización ya en curso',
      );
    }

    if (_queue.isEmpty) {
      isOfflineNotifier.value = false;
      return SyncBatchResult(
        totalPendientes: 0,
        sincronizadas: 0,
        fallidas: 0,
        mensaje: 'No hay ventas pendientes de sincronizar',
      );
    }

    _isSyncing = true;
    isSyncingNotifier.value = true;

    int sincronizadas = 0;
    int fallidas = 0;
    final totalInicial = _queue.length;

    debugPrint('[SyncManager] Iniciando sincronización de $totalInicial ventas offline...');

    // Procesa en orden FIFO estricto para mantener la cronología de transacciones
    final copias = List<OfflineVenta>.from(_queue);

    for (final venta in copias) {
      venta.estadoSync = 'SINCRONIZANDO';
      venta.intentosSync++;
      venta.fechaUltimoIntento = DateTime.now();

      try {
        final res = await _ventaService.registrarVentaCompleta(venta.toVentaEnvio());

        if (res.success) {
          // El servidor procesó o validó la idempotencia exitosamente
          _queue.removeWhere((v) => v.uuid == venta.uuid);
          sincronizadas++;
          debugPrint('[SyncManager] Sincronización exitosa: ${venta.localTicket} -> ${res.venta?.serieCorrelativo}');
        } else {
          final err = res.errorMessage ?? 'Error desconocido del servidor';
          venta.ultimoError = err;

          // Si el error es de conexión o timeout, el servidor sigue inaccesible
          if (err.toLowerCase().contains('conexión') ||
              err.toLowerCase().contains('red') ||
              err.toLowerCase().contains('timeout')) {
            venta.estadoSync = 'PENDIENTE';
            fallidas++;
            isOfflineNotifier.value = true;
            debugPrint('[SyncManager] Servidor aún no disponible. Pausando cola.');
            break; // Detiene el lote hasta el siguiente reintento
          } else {
            // Error de negocio (ej: cliente dado de baja, validación tributaria)
            venta.estadoSync = 'ERROR';
            fallidas++;
            debugPrint('[SyncManager] Error de negocio al sincronizar ${venta.localTicket}: $err');
          }
        }
      } catch (e) {
        venta.estadoSync = 'PENDIENTE';
        venta.ultimoError = e.toString();
        fallidas++;
        isOfflineNotifier.value = true;
        debugPrint('[SyncManager] Error de red inesperado al sincronizar: $e');
        break; // Detiene el lote
      }
    }

    await _saveQueue();
    _isSyncing = false;
    isSyncingNotifier.value = false;

    if (sincronizadas > 0) {
      lastSyncSuccessNotifier.value = DateTime.now();
      isOfflineNotifier.value = false;

      // Refresca catálogo e inventario oficial desde el backend
      ProductoService.invalidateCache();
      ProductoService().getProductos(forceRefresh: true);
      VentaService.notifyVentasChanged();
    }

    final resumen = SyncBatchResult(
      totalPendientes: totalInicial,
      sincronizadas: sincronizadas,
      fallidas: fallidas,
      mensaje: sincronizadas > 0
          ? '¡$sincronizadas venta(s) sincronizadas con éxito!'
          : 'No se pudo conectar con el servidor. Se reintentará automáticamente.',
    );

    return resumen;
  }

  /// Inicia el chequeo periódico en segundo plano para sincronizar cuando regrese internet
  void startAutoSync({Duration interval = const Duration(seconds: 25)}) {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(interval, (_) async {
      if (_queue.isNotEmpty && !_isSyncing) {
        syncPendingSales();
      }
    });
  }

  /// Cancela el temporizador de auto-sincronización
  void dispose() {
    _autoSyncTimer?.cancel();
  }
}
