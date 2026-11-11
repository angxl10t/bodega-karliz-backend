import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../../core/api_constants.dart';
import '../../core/karliz_sound_service.dart';
import '../../core/secure_storage_service.dart';

class PedidoWebItem {
  final int? idDetallePedidoWeb;
  final int idProducto;
  final String nombre;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;
  final String? badge;

  const PedidoWebItem({
    this.idDetallePedidoWeb,
    required this.idProducto,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    this.badge,
  });

  Map<String, dynamic> toJson() => {
        if (idDetallePedidoWeb != null) 'idDetallePedidoWeb': idDetallePedidoWeb,
        'idProducto': idProducto,
        'nombre': nombre,
        'cantidad': cantidad,
        'precioUnitario': precioUnitario,
        'subtotal': subtotal,
        if (badge != null) 'badge': badge,
      };

  factory PedidoWebItem.fromJson(Map<String, dynamic> json) => PedidoWebItem(
        idDetallePedidoWeb: (json['idDetallePedidoWeb'] as num?)?.toInt(),
        idProducto: (json['idProducto'] as num?)?.toInt() ?? 0,
        nombre: (json['nombre'] ?? json['nombreProducto'])?.toString() ?? 'Producto',
        cantidad: (json['cantidad'] as num?)?.toDouble() ?? 1.0,
        precioUnitario: (json['precioUnitario'] as num?)?.toDouble() ?? 0.0,
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
        badge: json['badge']?.toString(),
      );
}

class PedidoWeb {
  final int? idPedidoWeb;
  final String idPedido;
  final String? codigoPedido;
  final DateTime fecha;
  final String nombreCliente;
  final String? telefonoCliente;
  final String? notas;
  final List<PedidoWebItem> items;
  final double total;
  final double ahorroPromociones;
  final bool incluyeRetornables;
  String estado; // 'PENDIENTE', 'CARGADO_EN_POS', 'COMPLETADO', 'CANCELADO'

  PedidoWeb({
    this.idPedidoWeb,
    required this.idPedido,
    this.codigoPedido,
    required this.fecha,
    required this.nombreCliente,
    this.telefonoCliente,
    this.notas,
    required this.items,
    required this.total,
    this.ahorroPromociones = 0.0,
    this.incluyeRetornables = false,
    this.estado = 'PENDIENTE',
  });

  String get codigoDisplay => (codigoPedido != null && codigoPedido!.isNotEmpty)
      ? codigoPedido!
      : idPedido;

  Map<String, dynamic> toJson() => {
        if (idPedidoWeb != null) 'idPedidoWeb': idPedidoWeb,
        'idPedido': idPedido,
        if (codigoPedido != null) 'codigoPedido': codigoPedido,
        'fecha': fecha.toIso8601String(),
        'nombreCliente': nombreCliente,
        if (telefonoCliente != null) 'telefonoCliente': telefonoCliente,
        if (notas != null) 'notas': notas,
        'items': items.map((i) => i.toJson()).toList(),
        'total': total,
        'ahorroPromociones': ahorroPromociones,
        'incluyeRetornables': incluyeRetornables,
        'estado': estado,
      };

  factory PedidoWeb.fromJson(Map<String, dynamic> json) {
    final cod = json['codigoPedido']?.toString() ?? json['idPedido']?.toString() ?? '';
    return PedidoWeb(
      idPedidoWeb: (json['idPedidoWeb'] as num?)?.toInt(),
      idPedido: cod.isNotEmpty ? cod : 'WEB-${DateTime.now().millisecondsSinceEpoch % 100000}',
      codigoPedido: cod,
      fecha: DateTime.tryParse(json['fecha']?.toString() ?? '') ?? DateTime.now(),
      nombreCliente: json['nombreCliente']?.toString() ?? 'Cliente Web',
      telefonoCliente: json['telefonoCliente']?.toString(),
      notas: json['notas']?.toString(),
      items: ((json['items'] as List<dynamic>?) ?? [])
          .map((e) => PedidoWebItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      ahorroPromociones: (json['ahorroPromociones'] as num?)?.toDouble() ?? 0.0,
      incluyeRetornables: json['incluyeRetornables'] == true,
      estado: json['estado']?.toString() ?? 'PENDIENTE',
    );
  }
}

class PedidoWebService {
  static const String _storageKeyPrefix = 'cajaya_pedidos_web_guardados_v1';
  static final List<PedidoWeb> _pedidos = [];
  static final ValueNotifier<int> pedidosPendientesCountNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<bool> estaSincronizandoNotifier = ValueNotifier<bool>(false);

  static int _ultimaRevision = 0;
  static Timer? _pollingTimer;
  static ApiClient _apiClient = ApiClient();
  static void Function(PedidoWeb)? onNuevoPedidoRecibido;
  static bool _cleanupRegistered = false;

  static void _ensureCleanupRegistered() {
    if (_cleanupRegistered) return;
    _cleanupRegistered = true;
    SecureStorageService.registerSessionCleanup(resetSession);
  }

  @visibleForTesting
  static void setApiClientForTest(ApiClient client) {
    _apiClient = client;
  }

  static Future<String> _getStorageKey() async {
    final idBodega = await SecureStorageService.read('id_bodega');
    final tenant = (idBodega != null && idBodega.trim().isNotEmpty)
        ? idBodega.trim()
        : 'default';
    return '${_storageKeyPrefix}_$tenant';
  }

  /// Limpia pedidos en memoria, contadores y detiene cualquier sondeo activo al cambiar de cuenta/bodega.
  static void resetSession() {
    detenerPollingRevision();
    _pedidos.clear();
    _ultimaRevision = 0;
    pedidosPendientesCountNotifier.value = 0;
    estaSincronizandoNotifier.value = false;
    onNuevoPedidoRecibido = null;
  }

  static List<PedidoWeb> get pedidos => List.unmodifiable(_pedidos);

  static List<PedidoWeb> get pedidosPendientes =>
      _pedidos.where((p) => p.estado == 'PENDIENTE').toList();

  static Future<void> inicializar() async {
    _ensureCleanupRegistered();
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getStorageKey();
      final raw = prefs.getString(key) ?? prefs.getString(_storageKeyPrefix);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        _pedidos.clear();
        for (final item in decoded) {
          _pedidos.add(PedidoWeb.fromJson(Map<String, dynamic>.from(item as Map)));
        }
        _actualizarConteo();
      }
    } catch (_) {}
  }

  /// Inicia el sondeo inteligente cada 30 segundos (Zero-DB Hit cuando no hay cambios).
  static void iniciarPollingRevision() {
    _ensureCleanupRegistered();
    _pollingTimer?.cancel();
    // Verificación inicial inmediata
    unawaited(sincronizarConNube());

    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(sincronizarConNube());
    });
  }

  /// Detiene el sondeo cuando la pantalla POS entra en segundo plano.
  static void detenerPollingRevision() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Consulta la revisión en memoria del backend. Si cambió, descarga los pedidos.
  static Future<void> sincronizarConNube({bool forzar = false}) async {
    _ensureCleanupRegistered();
    if (estaSincronizandoNotifier.value) return;

    try {
      estaSincronizandoNotifier.value = true;

      if (!forzar) {
        final resRev = await _apiClient.get('/pedidos-web/revision?ultimaRevision=$_ultimaRevision');
        if (resRev.statusCode == 200) {
          final data = jsonDecode(utf8.decode(resRev.bodyBytes)) as Map<String, dynamic>;
          final bool hayCambio = data['hayCambio'] == true;
          final int revServidor = (data['revision'] as num?)?.toInt() ?? 0;
          final int conteoServidor = (data['conteoPendientes'] as num?)?.toInt() ?? 0;

          if (!hayCambio && revServidor <= _ultimaRevision) {
            // El backend confirmó que no hay cambios. Sincronizar solo el contador si difiere
            if (pedidosPendientesCountNotifier.value != conteoServidor) {
              pedidosPendientesCountNotifier.value = conteoServidor;
            }
            return;
          }
          _ultimaRevision = revServidor;
        } else {
          // Si no está autenticado o hay fallo de red, se mantiene el estado local
          return;
        }
      }

      // Descargar pedidos recientes de la nube
      final resPedidos = await _apiClient.get('/pedidos-web?estado=TODOS&limite=50');
      if (resPedidos.statusCode == 200) {
        final List<dynamic> listaJson = jsonDecode(utf8.decode(resPedidos.bodyBytes)) as List<dynamic>;
        final Set<String> codigosExistentes = _pedidos.map((p) => p.codigoDisplay).toSet();
        PedidoWeb? nuevoPedidoDetectado;

        final List<PedidoWeb> nuevosRemotos = [];
        for (final item in listaJson) {
          final p = PedidoWeb.fromJson(Map<String, dynamic>.from(item as Map));
          nuevosRemotos.add(p);
          if (p.estado == 'PENDIENTE' && !codigosExistentes.contains(p.codigoDisplay)) {
            nuevoPedidoDetectado = p;
          }
        }

        // Reemplazar o fusionar lista
        _pedidos.clear();
        _pedidos.addAll(nuevosRemotos);
        _actualizarConteo();
        await _persistir();

        // Si entró un pedido nuevo mientras la caja estaba abierta, emitir sonido de alerta
        if (nuevoPedidoDetectado != null) {
          unawaited(KarlizSoundService.instance.playBarcodeBeep());
          onNuevoPedidoRecibido?.call(nuevoPedidoDetectado);
        }
      }
    } catch (_) {
      // Silencioso ante pérdidas transitorias de conexión
    } finally {
      estaSincronizandoNotifier.value = false;
    }
  }

  /// Registra el pedido en memoria local y en la nube pública de CajaYa.
  static Future<void> registrarPedido(PedidoWeb pedido, {String? slugOrIdBodega}) async {
    _pedidos.removeWhere((p) => p.codigoDisplay == pedido.codigoDisplay);
    _pedidos.insert(0, pedido);
    _actualizarConteo();
    await _persistir();

    // Enviar a la nube en segundo plano
    unawaited(_enviarPedidoCloud(pedido, slugOrIdBodega));
  }

  static Future<void> _enviarPedidoCloud(PedidoWeb pedido, String? slugOrId) async {
    try {
      final identificador = (slugOrId != null && slugOrId.trim().isNotEmpty)
          ? slugOrId.trim()
          : '1';
      final url = Uri.parse('${ApiConstants.baseUrl}/public/catalogo/$identificador/pedidos');

      final body = {
        'idPedido': pedido.idPedido,
        'codigoPedido': pedido.codigoDisplay,
        'nombreCliente': pedido.nombreCliente,
        'telefonoCliente': pedido.telefonoCliente,
        'notas': pedido.notas,
        'total': pedido.total,
        'ahorroPromociones': pedido.ahorroPromociones,
        'incluyeRetornables': pedido.incluyeRetornables,
        'items': pedido.items.map((it) => {
          'idProducto': it.idProducto,
          'nombreProducto': it.nombre,
          'cantidad': it.cantidad,
          'precioUnitario': it.precioUnitario,
          'subtotal': it.subtotal,
          if (it.badge != null) 'badge': it.badge,
        }).toList(),
      };

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final idRemoto = (data['idPedidoWeb'] as num?)?.toInt();
        if (idRemoto != null) {
          final idx = _pedidos.indexWhere((p) => p.codigoDisplay == pedido.codigoDisplay);
          if (idx != -1) {
            _pedidos[idx] = PedidoWeb(
              idPedidoWeb: idRemoto,
              idPedido: data['codigoPedido']?.toString() ?? pedido.idPedido,
              codigoPedido: data['codigoPedido']?.toString() ?? pedido.codigoDisplay,
              fecha: pedido.fecha,
              nombreCliente: pedido.nombreCliente,
              telefonoCliente: pedido.telefonoCliente,
              notas: pedido.notas,
              items: pedido.items,
              total: pedido.total,
              ahorroPromociones: pedido.ahorroPromociones,
              incluyeRetornables: pedido.incluyeRetornables,
              estado: pedido.estado,
            );
            await _persistir();
          }
        }
      }
    } catch (_) {
      // Se mantiene en almacenamiento local como respaldo seguro
    }
  }

  static Future<void> marcarComoCargadoEnPos(String idPedido, {int? idPedidoWeb}) async {
    final idx = _pedidos.indexWhere((p) => p.codigoDisplay == idPedido || p.idPedido == idPedido);
    int? idWeb = idPedidoWeb;
    if (idx != -1) {
      _pedidos[idx].estado = 'CARGADO_EN_POS';
      idWeb ??= _pedidos[idx].idPedidoWeb;
      _actualizarConteo();
      await _persistir();
    }

    if (idWeb != null) {
      try {
        await _apiClient.put('/pedidos-web/$idWeb/estado?nuevoEstado=CARGADO_EN_POS', {});
      } catch (_) {}
    }
  }

  static Future<void> eliminarPedido(String idPedido, {int? idPedidoWeb}) async {
    final idx = _pedidos.indexWhere((p) => p.codigoDisplay == idPedido || p.idPedido == idPedido);
    int? idWeb = idPedidoWeb;
    if (idx != -1) {
      idWeb ??= _pedidos[idx].idPedidoWeb;
      _pedidos.removeAt(idx);
      _actualizarConteo();
      await _persistir();
    }

    if (idWeb != null) {
      try {
        await _apiClient.delete('/pedidos-web/$idWeb');
      } catch (_) {}
    }
  }

  static Future<List<PedidoWeb>> buscarPedidos(String query) async {
    _ensureCleanupRegistered();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return pedidos;

    // Búsqueda local inmediata
    final locales = _pedidos.where((p) {
      return p.codigoDisplay.toLowerCase().contains(q) ||
          p.nombreCliente.toLowerCase().contains(q) ||
          (p.telefonoCliente != null && p.telefonoCliente!.contains(q));
    }).toList();

    if (locales.isNotEmpty) return locales;

    // Si no está en local, intentar en la nube
    try {
      final res = await _apiClient.get('/pedidos-web/buscar?query=${Uri.encodeComponent(query)}&limite=20');
      if (res.statusCode == 200) {
        final List<dynamic> listaJson = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
        return listaJson.map((e) => PedidoWeb.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (_) {}

    return locales;
  }

  static void _actualizarConteo() {
    pedidosPendientesCountNotifier.value =
        _pedidos.where((p) => p.estado == 'PENDIENTE').length;
  }

  static Future<void> _persistir() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getStorageKey();
      final data = jsonEncode(_pedidos.map((p) => p.toJson()).toList());
      await prefs.setString(key, data);
    } catch (_) {}
  }
}
