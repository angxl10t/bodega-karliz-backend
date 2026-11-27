import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api_client.dart';
import '../api_constants.dart';
import '../karliz_sound_service.dart';
import '../secure_storage_service.dart';

class NotificacionItem {
  final int idNotificacion;
  final int idBodega;
  final int? idUsuarioDestinatario;
  final String rolDestinatario;
  final String tipo; // 'NUEVO_PEDIDO_WEB', 'STOCK_CRITICO'
  final String titulo;
  final String mensaje;
  final Map<String, dynamic>? metadata;
  final String prioridad; // 'ALTA', 'MEDIA', 'BAJA'
  bool leido;
  final DateTime fechaCreacion;
  final DateTime? fechaLeido;

  NotificacionItem({
    required this.idNotificacion,
    required this.idBodega,
    this.idUsuarioDestinatario,
    required this.rolDestinatario,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    this.metadata,
    this.prioridad = 'MEDIA',
    this.leido = false,
    required this.fechaCreacion,
    this.fechaLeido,
  });

  bool get esPedidoWeb => tipo == 'NUEVO_PEDIDO_WEB';
  bool get esStockCritico => tipo == 'STOCK_CRITICO';

  factory NotificacionItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? meta;
    if (json['metadataJson'] != null &&
        json['metadataJson'].toString().isNotEmpty) {
      try {
        meta =
            jsonDecode(json['metadataJson'].toString()) as Map<String, dynamic>;
      } catch (_) {}
    }

    return NotificacionItem(
      idNotificacion: (json['idNotificacion'] as num?)?.toInt() ?? 0,
      idBodega: (json['idBodega'] as num?)?.toInt() ?? 0,
      idUsuarioDestinatario: (json['idUsuarioDestinatario'] as num?)?.toInt(),
      rolDestinatario: (json['rolDestinatario']?.toString() ?? 'TODOS')
          .toUpperCase(),
      tipo: (json['tipo']?.toString() ?? 'GENERAL').toUpperCase(),
      titulo: json['titulo']?.toString() ?? 'Notificación',
      mensaje: json['mensaje']?.toString() ?? '',
      metadata: meta,
      prioridad: (json['prioridad']?.toString() ?? 'MEDIA').toUpperCase(),
      leido: json['leido'] == true,
      fechaCreacion: json['fechaCreacion'] != null
          ? (DateTime.tryParse(json['fechaCreacion'].toString()) ??
                DateTime.now())
          : DateTime.now(),
      fechaLeido: json['fechaLeido'] != null
          ? DateTime.tryParse(json['fechaLeido'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'idNotificacion': idNotificacion,
    'idBodega': idBodega,
    'idUsuarioDestinatario': idUsuarioDestinatario,
    'rolDestinatario': rolDestinatario,
    'tipo': tipo,
    'titulo': titulo,
    'mensaje': mensaje,
    if (metadata != null) 'metadataJson': jsonEncode(metadata),
    'prioridad': prioridad,
    'leido': leido,
    'fechaCreacion': fechaCreacion.toIso8601String(),
    if (fechaLeido != null) 'fechaLeido': fechaLeido!.toIso8601String(),
  };
}

/// Servicio central de notificaciones en tiempo real (Server-Sent Events)
/// Aislamiento por usuario y rol en mostrador.
class NotificacionService {
  NotificacionService._();
  static final NotificacionService instance = NotificacionService._();

  static final ValueNotifier<List<NotificacionItem>> notificacionesNotifier =
      ValueNotifier<List<NotificacionItem>>([]);
  static final ValueNotifier<int> noLeidasCountNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(
    false,
  );

  static final StreamController<NotificacionItem> _streamController =
      StreamController<NotificacionItem>.broadcast();
  static Stream<NotificacionItem> get onNotificacionRecibida =>
      _streamController.stream;

  static http.Client? _sseClient;
  static Timer? _reconnectTimer;
  static bool _isActive = false;
  static int _reconnectDelaySeconds = 3;
  static bool _cleanupRegistered = false;
  static ApiClient _apiClient = ApiClient();

  @visibleForTesting
  static void setApiClientForTest(ApiClient client) {
    _apiClient = client;
  }

  static void _ensureCleanupRegistered() {
    if (_cleanupRegistered) return;
    _cleanupRegistered = true;
    SecureStorageService.registerSessionCleanup(resetSession);
  }

  /// Inicia la escucha continua Server-Sent Events (SSE)
  static Future<void> iniciarStream() async {
    _ensureCleanupRegistered();
    if (_isActive) return;
    _isActive = true;
    _reconnectDelaySeconds = 3;

    // Cargar historial inicial y conteo de no leídas
    await sincronizarHistorial();

    _conectarSSE();
  }

  /// Conecta o reconecta el canal SSE
  static Future<void> _conectarSSE() async {
    if (!_isActive) return;

    _sseClient?.close();
    _sseClient = http.Client();

    try {
      final token = await SecureStorageService.read('jwt_token');
      if (token == null || token.isEmpty) {
        isConnectedNotifier.value = false;
        _programarReconexion();
        return;
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/notificaciones/stream');
      final request = http.Request('GET', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Accept'] = 'text/event-stream'
        ..headers['Cache-Control'] = 'no-cache';

      final response = await _sseClient!.send(request);

      if (response.statusCode == 200) {
        isConnectedNotifier.value = true;
        _reconnectDelaySeconds = 3; // Reset backoff

        String buffer = '';
        String currentEvent = 'message';

        await for (final chunk in response.stream.transform(utf8.decoder)) {
          if (!_isActive) break;

          buffer += chunk;
          while (buffer.contains('\n')) {
            final newlineIdx = buffer.indexOf('\n');
            final line = buffer.substring(0, newlineIdx).trim();
            buffer = buffer.substring(newlineIdx + 1);

            if (line.isEmpty) {
              currentEvent = 'message';
              continue;
            }

            if (line.startsWith(':')) {
              // Heartbeat SSE comment (ping), mantener activo
              continue;
            }

            if (line.startsWith('event:')) {
              currentEvent = line.substring(6).trim();
            } else if (line.startsWith('data:')) {
              final rawData = line.substring(5).trim();
              _procesarMensajeSSE(currentEvent, rawData);
            }
          }
        }
      } else {
        isConnectedNotifier.value = false;
      }
    } catch (_) {
      isConnectedNotifier.value = false;
    }

    _programarReconexion();
  }

  static void _procesarMensajeSSE(String eventName, String rawData) {
    try {
      final decoded = jsonDecode(rawData);
      if (decoded is! Map<String, dynamic>) return;

      if (eventName == 'INIT') {
        final noLeidas = (decoded['noLeidas'] as num?)?.toInt() ?? 0;
        noLeidasCountNotifier.value = noLeidas;
      } else if (eventName == 'notificacion') {
        final notif = NotificacionItem.fromJson(decoded);

        // Insertar al inicio de la lista
        final listaActual = List<NotificacionItem>.from(
          notificacionesNotifier.value,
        );
        listaActual.removeWhere(
          (n) => n.idNotificacion == notif.idNotificacion,
        );
        listaActual.insert(0, notif);
        notificacionesNotifier.value = listaActual;

        if (!notif.leido) {
          noLeidasCountNotifier.value = noLeidasCountNotifier.value + 1;
        }

        // Retroalimentación auditiva y disparo de stream para Banner In-App
        if (notif.esPedidoWeb) {
          unawaited(KarlizSoundService.instance.playCashChime());
        } else if (notif.esStockCritico) {
          unawaited(KarlizSoundService.instance.playErrorBeep());
        } else {
          unawaited(KarlizSoundService.instance.playBarcodeBeep());
        }

        _streamController.add(notif);
      }
    } catch (_) {}
  }

  static void _programarReconexion() {
    if (!_isActive) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelaySeconds), () {
      _reconnectDelaySeconds = (_reconnectDelaySeconds * 2).clamp(3, 30);
      _conectarSSE();
    });
  }

  /// Carga el historial de notificaciones desde el backend REST
  static Future<void> sincronizarHistorial({int limite = 30}) async {
    try {
      final res = await _apiClient.get('/notificaciones?limite=$limite');
      if (res.statusCode == 200) {
        final List<dynamic> data =
            jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
        final items = data
            .whereType<Map>()
            .map((m) => NotificacionItem.fromJson(Map<String, dynamic>.from(m)))
            .toList();

        notificacionesNotifier.value = items;
        noLeidasCountNotifier.value = items.where((n) => !n.leido).length;
      }
    } catch (_) {}
  }

  /// Marca una notificación como leída
  static Future<void> marcarComoLeida(int idNotificacion) async {
    try {
      final lista = List<NotificacionItem>.from(notificacionesNotifier.value);
      final idx = lista.indexWhere((n) => n.idNotificacion == idNotificacion);
      if (idx != -1 && !lista[idx].leido) {
        lista[idx].leido = true;
        notificacionesNotifier.value = lista;
        noLeidasCountNotifier.value = (noLeidasCountNotifier.value - 1).clamp(
          0,
          9999,
        );
      }

      await _apiClient.put('/notificaciones/$idNotificacion/leer', {});
    } catch (_) {}
  }

  /// Marca todas las notificaciones como leídas
  static Future<void> marcarTodasComoLeidas() async {
    try {
      final lista = List<NotificacionItem>.from(notificacionesNotifier.value);
      for (final item in lista) {
        item.leido = true;
      }
      notificacionesNotifier.value = lista;
      noLeidasCountNotifier.value = 0;

      await _apiClient.put('/notificaciones/marcar-todas', {});
    } catch (_) {}
  }

  /// Detiene el canal SSE al cerrar sesión
  static void detenerStream() {
    _isActive = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _sseClient?.close();
    _sseClient = null;
    isConnectedNotifier.value = false;
  }

  /// Resetea la memoria local al cambiar de inquilino o cerrar sesión
  static void resetSession() {
    detenerStream();
    notificacionesNotifier.value = [];
    noLeidasCountNotifier.value = 0;
  }
}
