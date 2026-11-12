import 'dart:convert';

import 'secure_storage_service.dart';

/// Modelo de datos para la configuración del hardware de impresión térmica ESC/POS
/// y la personalización del comprobante / pie de ticket.
class ConfiguracionTicket {
  /// Ancho de papel: 32 columnas (58 mm) o 48 columnas (80 mm)
  final int anchoPapel;

  /// Si se debe enviar el pulso ESC/POS a la gaveta de dinero conectada por RJ11/RJ12
  final bool abrirGaveta;

  /// Si se debe imprimir inmediatamente al completar la venta sin esperar confirmación
  final bool impresionAutomatica;

  /// Modo de comunicación:
  /// - 'bluetooth_nativo': Impresión directa nativa Android vía Bluetooth SPP (sin RawBT)
  /// - 'rawbt': Aplicación / Driver RawBT vía URI scheme (Bluetooth SPP/BLE y USB)
  /// - 'servidor_local': Servicio local HTTP o bridge de impresión (ej. 127.0.0.1:40213)
  /// - 'navegador': Diálogo de impresión del navegador o compartir
  final String modoConexion;

  /// Dirección del servidor local de impresión (por defecto RawBT Web Bridge)
  final String servidorLocalUrl;

  /// Mensaje principal de agradecimiento al final del ticket
  final String mensajeAgradecimiento;

  /// Mensaje secundario (garantía, cambios, etc.)
  final String mensajeSecundario;

  /// Horario de atención de la bodega
  final String horarioAtencion;

  /// Redes sociales o teléfonos de contacto (WhatsApp, Facebook, etc.)
  final String redesSociales;

  /// Si se debe imprimir código QR en el pie de ticket
  final bool mostrarQr;

  /// Tipo de QR: 'YAPE', 'PLIN', 'SUNAT', 'PERSONALIZADO'
  final String tipoQr;

  /// Número de teléfono o enlace para cobrar por Yape / Plin
  final String numeroQr;

  /// Nombre del titular de la cuenta de Yape / Plin
  final String titularQr;

  /// Nombre descriptivo de la impresora Bluetooth SPP vinculada (ej. 'InnerPrinter')
  final String bluetoothDeviceName;

  /// Dirección MAC de la impresora Bluetooth SPP vinculada (ej. '00:11:22:33:44:55')
  final String bluetoothDeviceAddress;

  const ConfiguracionTicket({
    this.anchoPapel = 32,
    this.abrirGaveta = true,
    this.impresionAutomatica = false,
    this.modoConexion = 'rawbt',
    this.servidorLocalUrl = 'http://127.0.0.1:40213/',
    this.mensajeAgradecimiento = '¡Gracias por su compra! Vuelva pronto.',
    this.mensajeSecundario = 'Conserve su comprobante',
    this.horarioAtencion = 'Atención: Lun-Dom 7:00 am - 11:00 pm',
    this.redesSociales = '',
    this.mostrarQr = true,
    this.tipoQr = 'YAPE',
    this.numeroQr = '',
    this.titularQr = '',
    this.bluetoothDeviceName = '',
    this.bluetoothDeviceAddress = '',
  });

  /// Clonar con campos actualizados
  ConfiguracionTicket copyWith({
    int? anchoPapel,
    bool? abrirGaveta,
    bool? impresionAutomatica,
    String? modoConexion,
    String? servidorLocalUrl,
    String? mensajeAgradecimiento,
    String? mensajeSecundario,
    String? horarioAtencion,
    String? redesSociales,
    bool? mostrarQr,
    String? tipoQr,
    String? numeroQr,
    String? titularQr,
    String? bluetoothDeviceName,
    String? bluetoothDeviceAddress,
  }) {
    return ConfiguracionTicket(
      anchoPapel: anchoPapel ?? this.anchoPapel,
      abrirGaveta: abrirGaveta ?? this.abrirGaveta,
      impresionAutomatica: impresionAutomatica ?? this.impresionAutomatica,
      modoConexion: modoConexion ?? this.modoConexion,
      servidorLocalUrl: servidorLocalUrl ?? this.servidorLocalUrl,
      mensajeAgradecimiento:
          mensajeAgradecimiento ?? this.mensajeAgradecimiento,
      mensajeSecundario: mensajeSecundario ?? this.mensajeSecundario,
      horarioAtencion: horarioAtencion ?? this.horarioAtencion,
      redesSociales: redesSociales ?? this.redesSociales,
      mostrarQr: mostrarQr ?? this.mostrarQr,
      tipoQr: tipoQr ?? this.tipoQr,
      numeroQr: numeroQr ?? this.numeroQr,
      titularQr: titularQr ?? this.titularQr,
      bluetoothDeviceName: bluetoothDeviceName ?? this.bluetoothDeviceName,
      bluetoothDeviceAddress:
          bluetoothDeviceAddress ?? this.bluetoothDeviceAddress,
    );
  }

  /// Serialización a Map
  Map<String, dynamic> toJson() {
    return {
      'anchoPapel': anchoPapel,
      'abrirGaveta': abrirGaveta,
      'impresionAutomatica': impresionAutomatica,
      'modoConexion': modoConexion,
      'servidorLocalUrl': servidorLocalUrl,
      'mensajeAgradecimiento': mensajeAgradecimiento,
      'mensajeSecundario': mensajeSecundario,
      'horarioAtencion': horarioAtencion,
      'redesSociales': redesSociales,
      'mostrarQr': mostrarQr,
      'tipoQr': tipoQr,
      'numeroQr': numeroQr,
      'titularQr': titularQr,
      'bluetoothDeviceName': bluetoothDeviceName,
      'bluetoothDeviceAddress': bluetoothDeviceAddress,
    };
  }

  /// Deserialización desde Map
  factory ConfiguracionTicket.fromJson(Map<String, dynamic> json) {
    return ConfiguracionTicket(
      anchoPapel: json['anchoPapel'] as int? ?? 32,
      abrirGaveta: json['abrirGaveta'] as bool? ?? true,
      impresionAutomatica: json['impresionAutomatica'] as bool? ?? false,
      modoConexion: json['modoConexion'] as String? ?? 'rawbt',
      servidorLocalUrl:
          json['servidorLocalUrl'] as String? ?? 'http://127.0.0.1:40213/',
      mensajeAgradecimiento:
          json['mensajeAgradecimiento'] as String? ??
          '¡Gracias por su compra! Vuelva pronto.',
      mensajeSecundario:
          json['mensajeSecundario'] as String? ?? 'Conserve su comprobante',
      horarioAtencion:
          json['horarioAtencion'] as String? ??
          'Atención: Lun-Dom 7:00 am - 11:00 pm',
      redesSociales: json['redesSociales'] as String? ?? '',
      mostrarQr: json['mostrarQr'] as bool? ?? true,
      tipoQr: json['tipoQr'] as String? ?? 'YAPE',
      numeroQr: json['numeroQr'] as String? ?? '',
      titularQr: json['titularQr'] as String? ?? '',
      bluetoothDeviceName: json['bluetoothDeviceName'] as String? ?? '',
      bluetoothDeviceAddress: json['bluetoothDeviceAddress'] as String? ?? '',
    );
  }
}

/// Servicio singleton para persistir y cargar la configuración de impresión térmica
class ConfiguracionTicketService {
  static const String _defaultStorageKey = 'cajaya_config_ticket_pos';
  static ConfiguracionTicket _actual = const ConfiguracionTicket();
  static bool _sessionCleanupRegistered = false;

  static void _ensureSessionCleanupRegistered() {
    if (!_sessionCleanupRegistered) {
      _sessionCleanupRegistered = true;
      SecureStorageService.registerSessionCleanup(resetSession);
    }
  }

  /// Limpia la configuración en memoria de la bodega al cerrar sesión
  static void resetSession() {
    _actual = const ConfiguracionTicket();
  }

  /// Clave de almacenamiento aislada por bodega para evitar fuga de número Yape/QR
  static Future<String> _getStorageKey() async {
    try {
      final idBodega = await SecureStorageService.read('id_bodega');
      if (idBodega != null && idBodega.trim().isNotEmpty) {
        return 'cajaya_config_ticket_pos_${idBodega.trim()}';
      }
    } catch (_) {}
    return _defaultStorageKey;
  }

  /// Configuración en memoria disponible síncronamente
  static ConfiguracionTicket get actual => _actual;

  /// Carga la configuración persistida desde SecureStorageService
  static Future<ConfiguracionTicket> cargar() async {
    _ensureSessionCleanupRegistered();
    try {
      final key = await _getStorageKey();
      String? raw = await SecureStorageService.read(key);
      if ((raw == null || raw.trim().isEmpty) && key != _defaultStorageKey) {
        // Fallback para migración de configuración previa sin prefijo
        raw = await SecureStorageService.read(_defaultStorageKey);
      }
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _actual = ConfiguracionTicket.fromJson(decoded);
        return _actual;
      }
    } catch (_) {}
    _actual = const ConfiguracionTicket();
    return _actual;
  }

  /// Guarda y actualiza la configuración persistida
  static Future<void> guardar(ConfiguracionTicket config) async {
    _ensureSessionCleanupRegistered();
    _actual = config;
    try {
      final key = await _getStorageKey();
      final raw = jsonEncode(config.toJson());
      await SecureStorageService.write(key, raw);
    } catch (_) {}
  }
}
