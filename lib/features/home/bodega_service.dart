import 'dart:convert';

import '../../core/api_client.dart';
import '../../core/secure_storage_service.dart';

class BodegaInfo {
  final int idBodega;
  final String nombreComercial;
  final String? rucDni;
  final String? direccion;
  final String? telefono;
  final String? logoUrl;
  final String colorPrimario;
  final String? lemaComercial;
  final String plan;
  final bool estado;
  final String? fechaVencimientoPlan;
  final bool facturacionSunatActiva;
  final String regimenTributario;
  final bool esNuevoRus;
  final String? sunatProveedor;
  final String? sunatRucEmisor;
  final String? sunatUsuarioSol;
  final String? serieBoleta;
  final String? serieFactura;
  final int? limiteProductos;
  final int? totalProductosActivos;
  final bool limiteAlcanzado;

  BodegaInfo({
    required this.idBodega,
    required this.nombreComercial,
    this.rucDni,
    this.direccion,
    this.telefono,
    this.logoUrl,
    required this.colorPrimario,
    this.lemaComercial,
    required this.plan,
    required this.estado,
    this.fechaVencimientoPlan,
    this.facturacionSunatActiva = false,
    this.regimenTributario = 'NUEVO_RUS',
    bool? esNuevoRus,
    this.sunatProveedor,
    this.sunatRucEmisor,
    this.sunatUsuarioSol,
    this.serieBoleta,
    this.serieFactura,
    this.limiteProductos,
    this.totalProductosActivos,
    this.limiteAlcanzado = false,
  }) : esNuevoRus = esNuevoRus ?? (regimenTributario == 'NUEVO_RUS');

  BodegaInfo copyWith({
    int? idBodega,
    String? nombreComercial,
    String? rucDni,
    String? direccion,
    String? telefono,
    String? logoUrl,
    String? colorPrimario,
    String? lemaComercial,
    String? plan,
    bool? estado,
    String? fechaVencimientoPlan,
    bool? facturacionSunatActiva,
    String? regimenTributario,
    bool? esNuevoRus,
    String? sunatProveedor,
    String? sunatRucEmisor,
    String? sunatUsuarioSol,
    String? serieBoleta,
    String? serieFactura,
    int? limiteProductos,
    int? totalProductosActivos,
    bool? limiteAlcanzado,
  }) {
    return BodegaInfo(
      idBodega: idBodega ?? this.idBodega,
      nombreComercial: nombreComercial ?? this.nombreComercial,
      rucDni: rucDni ?? this.rucDni,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      logoUrl: logoUrl ?? this.logoUrl,
      colorPrimario: colorPrimario ?? this.colorPrimario,
      lemaComercial: lemaComercial ?? this.lemaComercial,
      plan: plan ?? this.plan,
      estado: estado ?? this.estado,
      fechaVencimientoPlan: fechaVencimientoPlan ?? this.fechaVencimientoPlan,
      facturacionSunatActiva:
          facturacionSunatActiva ?? this.facturacionSunatActiva,
      regimenTributario: regimenTributario ?? this.regimenTributario,
      esNuevoRus: esNuevoRus ?? this.esNuevoRus,
      sunatProveedor: sunatProveedor ?? this.sunatProveedor,
      sunatRucEmisor: sunatRucEmisor ?? this.sunatRucEmisor,
      sunatUsuarioSol: sunatUsuarioSol ?? this.sunatUsuarioSol,
      serieBoleta: serieBoleta ?? this.serieBoleta,
      serieFactura: serieFactura ?? this.serieFactura,
      limiteProductos: limiteProductos ?? this.limiteProductos,
      totalProductosActivos:
          totalProductosActivos ?? this.totalProductosActivos,
      limiteAlcanzado: limiteAlcanzado ?? this.limiteAlcanzado,
    );
  }

  factory BodegaInfo.fromJson(Map<String, dynamic> json) {
    final reg = json['regimenTributario'] as String? ?? 'NUEVO_RUS';
    final isRus = json['esNuevoRus'] == true || reg == 'NUEVO_RUS';
    return BodegaInfo(
      idBodega: json['idBodega'] is int
          ? json['idBodega']
          : int.parse(json['idBodega']?.toString() ?? '1'),
      nombreComercial: json['nombreComercial'] ?? 'CajaYa',
      rucDni: json['rucDni'],
      direccion: json['direccion'],
      telefono: json['telefono'],
      logoUrl: json['logoUrl'],
      colorPrimario: json['colorPrimario'] ?? '#2563EB',
      lemaComercial: json['lemaComercial'],
      plan: json['plan'] ?? 'BASICO',
      estado: json['estado'] == true,
      fechaVencimientoPlan: json['fechaVencimientoPlan'],
      facturacionSunatActiva: json['facturacionSunatActiva'] == true,
      regimenTributario: reg,
      esNuevoRus: isRus,
      sunatProveedor: json['sunatProveedor'],
      sunatRucEmisor: json['sunatRucEmisor'],
      sunatUsuarioSol: json['sunatUsuarioSol'],
      serieBoleta: json['serieBoleta'],
      serieFactura: json['serieFactura'],
      limiteProductos: json['limiteProductos'] as int?,
      totalProductosActivos: (json['totalProductosActivos'] as num?)?.toInt(),
      limiteAlcanzado: json['limiteAlcanzado'] == true,
    );
  }
}

class BodegaService {
  static const Duration _cacheTtl = Duration(seconds: 30);
  static bool _cleanupRegistered = false;
  static BodegaInfo? _cachedMiBodega;
  static DateTime? _cachedAt;
  static Future<BodegaInfo?>? _inFlightMiBodega;

  final ApiClient _client;

  BodegaService({ApiClient? client}) : _client = client ?? ApiClient() {
    _ensureCleanupRegistered();
  }

  static void _ensureCleanupRegistered() {
    if (_cleanupRegistered) return;
    _cleanupRegistered = true;
    SecureStorageService.registerSessionCleanup(clearCache);
  }

  /// Limpia caché en memoria de la bodega activa (ej. al cerrar sesión o en tests).
  static void clearCache() {
    _cachedMiBodega = null;
    _cachedAt = null;
    _inFlightMiBodega = null;
  }

  static void _actualizarCacheLocal(BodegaInfo info) {
    _cachedMiBodega = info;
    _cachedAt = DateTime.now();
  }

  static Future<void> _persistirBodegaEnStorage(BodegaInfo info) async {
    final writes = <Future<void>>[
      SecureStorageService.write('nombre_bodega', info.nombreComercial),
      SecureStorageService.write('plan_bodega', info.plan),
      SecureStorageService.write('regimen_tributario', info.regimenTributario),
      SecureStorageService.write(
        'facturacion_sunat_activa',
        info.facturacionSunatActiva.toString(),
      ),
      SecureStorageService.write('color_primario', info.colorPrimario),
    ];
    if (info.rucDni != null) {
      writes.add(SecureStorageService.write('ruc_bodega', info.rucDni!));
    }
    if (info.direccion != null) {
      writes.add(
        SecureStorageService.write('direccion_bodega', info.direccion!),
      );
    }
    if (info.telefono != null) {
      writes.add(SecureStorageService.write('telefono_bodega', info.telefono!));
    }
    if (info.lemaComercial != null) {
      writes.add(
        SecureStorageService.write('lema_comercial', info.lemaComercial!),
      );
    }
    if (info.logoUrl != null) {
      writes.add(SecureStorageService.write('logo_url', info.logoUrl!));
    }
    await Future.wait(writes);
  }

  Future<BodegaInfo?> obtenerMiBodega({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedMiBodega != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return _cachedMiBodega;
    }

    if (!forceRefresh && _inFlightMiBodega != null) {
      return _inFlightMiBodega!;
    }

    late final Future<BodegaInfo?> requestFuture;
    requestFuture = _fetchAndCacheMiBodega().whenComplete(() {
      if (identical(_inFlightMiBodega, requestFuture)) {
        _inFlightMiBodega = null;
      }
    });
    _inFlightMiBodega = requestFuture;
    return requestFuture;
  }

  Future<BodegaInfo?> _fetchAndCacheMiBodega() async {
    try {
      final response = await _client.get('/bodegas/mi-bodega');
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final info = BodegaInfo.fromJson(data);
        _actualizarCacheLocal(info);
        await _persistirBodegaEnStorage(info);
        return info;
      }
    } catch (_) {}
    return null;
  }

  Future<List<BodegaInfo>> listarTodas() async {
    try {
      final response = await _client.get('/bodegas');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => BodegaInfo.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<BodegaInfo> actualizarConfiguracion({
    required String nombreComercial,
    String? rucDni,
    String? direccion,
    String? telefono,
    String? lemaComercial,
    String? colorPrimario,
    String? logoUrl,
  }) async {
    final body = <String, dynamic>{
      'nombreComercial': nombreComercial,
      'rucDni': rucDni,
      'direccion': direccion,
      'telefono': telefono,
      'lemaComercial': lemaComercial,
      'colorPrimario': colorPrimario,
      'logoUrl': logoUrl,
    };

    final response = await _client.put('/bodegas/configuracion', body);
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final info = BodegaInfo.fromJson(data);
      _actualizarCacheLocal(info);
      await _persistirBodegaEnStorage(info);
      return info;
    }

    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo guardar la configuración de la tienda',
    );
    throw Exception(errorMsg);
  }

  /// Solución 1: Registrar y confirmar pago directo vía Yape / Plin (0% comisiones)
  Future<BodegaInfo> registrarPagoYape({
    required String codigoOperacion,
    required String plan,
    required double monto,
    required String billetera,
  }) async {
    final body = <String, dynamic>{
      'codigoOperacion': codigoOperacion,
      'plan': plan,
      'monto': monto,
      'billetera': billetera,
    };

    final response = await _client.post('/bodegas/pago-yape', body);
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final info = BodegaInfo.fromJson(data);
      _actualizarCacheLocal(info);
      await SecureStorageService.write('plan_bodega', info.plan);
      return info;
    }

    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo registrar el pago de la suscripción',
    );
    throw Exception(errorMsg);
  }

  /// Reportar comprobante de pago para validación manual y conciliación por macro
  Future<bool> reportarPagoManual({
    required String codigoOperacion,
    required String plan,
    required double monto,
    required String billetera,
  }) async {
    final body = <String, dynamic>{
      'codigoOperacion': codigoOperacion,
      'plan': plan,
      'monto': monto,
      'billetera': billetera,
    };

    final response = await _client.post('/bodegas/reportar-pago-manual', body);
    if (response.statusCode == 200) {
      return true;
    }

    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo reportar el comprobante de pago',
    );
    throw Exception(errorMsg);
  }

  /// Solución 2: Configurar y activar el Módulo SUNAT (Exclusivo Administrador)
  Future<BodegaInfo> actualizarConfiguracionSunat({
    required bool activa,
    String? regimenTributario,
    String? proveedor,
    String? rucEmisor,
    String? usuarioSol,
    String? tokenApi,
    String? serieBoleta,
    String? serieFactura,
  }) async {
    final body = <String, dynamic>{
      'facturacionSunatActiva': activa,
      'regimenTributario': regimenTributario ?? 'NUEVO_RUS',
      'sunatProveedor': proveedor,
      'sunatRucEmisor': rucEmisor,
      'sunatUsuarioSol': usuarioSol,
      'sunatTokenApi': tokenApi,
      'serieBoleta': serieBoleta,
      'serieFactura': serieFactura,
    };

    final response = await _client.put('/bodegas/configuracion-sunat', body);
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final info = BodegaInfo.fromJson(data);
      _actualizarCacheLocal(info);
      await Future.wait([
        SecureStorageService.write(
          'regimen_tributario',
          info.regimenTributario,
        ),
        SecureStorageService.write(
          'facturacion_sunat_activa',
          info.facturacionSunatActiva.toString(),
        ),
      ]);
      return info;
    }

    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo actualizar la configuración de SUNAT',
    );
    throw Exception(errorMsg);
  }

  /// Consulta del Libro Mayor de Pagos y Renovaciones de la Bodega
  Future<List<PagoSuscripcionItem>> listarMisPagos() async {
    try {
      final response = await _client.get('/bodegas/mis-pagos');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => PagoSuscripcionItem.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Consulta Global de TODOS los Pagos (Exclusivo Superadmin)
  Future<List<PagoSuscripcionItem>> listarTodosLosPagos() async {
    try {
      final response = await _client.get('/bodegas/todos-los-pagos');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => PagoSuscripcionItem.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Activar o Suspender una bodega del sistema (Exclusivo Superadmin)
  Future<BodegaInfo> cambiarEstadoBodega(int idBodega, bool activo) async {
    final response = await _client.put(
      '/bodegas/$idBodega/estado?activo=$activo',
      {},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return BodegaInfo.fromJson(data);
    }
    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo cambiar el estado de la bodega',
    );
    throw Exception(errorMsg);
  }

  /// Cambiar o extender el plan de una bodega (Exclusivo Superadmin)
  Future<BodegaInfo> cambiarPlanBodega(
    int idBodega,
    String plan, {
    int dias = 30,
  }) async {
    final response = await _client.put(
      '/bodegas/$idBodega/plan?plan=$plan&dias=$dias',
      {},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return BodegaInfo.fromJson(data);
    }
    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo actualizar el plan de la bodega',
    );
    throw Exception(errorMsg);
  }

  /// Métricas consolidadas del SaaS (Exclusivo Superadmin)
  Future<Map<String, dynamic>> obtenerMetricasSistema() async {
    try {
      final response = await _client.get('/bodegas/metricas-sistema');
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  /// Monitoreo de salud y telemetría JVM del servidor
  Future<Map<String, dynamic>> obtenerHealthServidor() async {
    try {
      final response = await _client.get('/health');
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  /// Provisionar una nueva bodega completa desde el Superadmin
  Future<BodegaInfo> provisionarBodega(Map<String, dynamic> data) async {
    final response = await _client.post('/bodegas/provisionar', data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      final resData = jsonDecode(utf8.decode(response.bodyBytes));
      return BodegaInfo.fromJson(resData);
    }
    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo crear la bodega',
    );
    throw Exception(errorMsg);
  }

  /// Cambiar estado de un pago en el libro mayor de suscripciones (Superadmin)
  Future<PagoSuscripcionItem> cambiarEstadoPago(
    int idPago,
    String nuevoEstado,
  ) async {
    final response = await _client.put(
      '/bodegas/pagos/$idPago/estado?estado=$nuevoEstado',
      {},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return PagoSuscripcionItem.fromJson(data);
    }
    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo actualizar el estado del pago',
    );
    throw Exception(errorMsg);
  }

  /// Obtener comunicado global activo del SaaS
  Future<Map<String, dynamic>> obtenerAnuncioGlobal() async {
    try {
      final response = await _client.get('/bodegas/anuncio-global');
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  /// Publicar o actualizar comunicado global (Superadmin)
  Future<Map<String, dynamic>> publicarAnuncioGlobal(
    String mensaje, {
    String tipo = 'INFO',
  }) async {
    final response = await _client.post('/bodegas/anuncio-global', {
      'mensaje': mensaje,
      'tipo': tipo,
    });
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo publicar el anuncio',
    );
    throw Exception(errorMsg);
  }

  /// Eliminar comunicado global (Superadmin)
  Future<void> eliminarAnuncioGlobal() async {
    final response = await _client.delete('/bodegas/anuncio-global');
    if (response.statusCode != 200) {
      final errorMsg = ApiClient.extractErrorMessage(
        response,
        'No se pudo eliminar el anuncio',
      );
      throw Exception(errorMsg);
    }
  }

  /// Listar productos del Preset Global de Starter Pack (Exclusivo Superadmin)
  Future<List<StarterPackPresetItem>> listarStarterPackPresets() async {
    try {
      final response = await _client.get('/superadmin/starter-pack');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data
            .map((json) => StarterPackPresetItem.fromJson(json))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Crear nuevo producto en el Preset Global de Starter Pack (Exclusivo Superadmin)
  Future<StarterPackPresetItem> crearStarterPackPreset(
    Map<String, dynamic> data,
  ) async {
    final response = await _client.post('/superadmin/starter-pack', data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return StarterPackPresetItem.fromJson(json);
    }
    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo registrar el producto en el Preset Starter Pack',
    );
    throw Exception(errorMsg);
  }

  /// Actualizar un producto existente del Preset Global (Exclusivo Superadmin)
  Future<StarterPackPresetItem> actualizarStarterPackPreset(
    int idPreset,
    Map<String, dynamic> data,
  ) async {
    final response = await _client.put(
      '/superadmin/starter-pack/$idPreset',
      data,
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return StarterPackPresetItem.fromJson(json);
    }
    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo actualizar el producto en el Preset Starter Pack',
    );
    throw Exception(errorMsg);
  }

  /// Eliminar un producto del Preset Global (Exclusivo Superadmin)
  Future<void> eliminarStarterPackPreset(int idPreset) async {
    final response = await _client.delete('/superadmin/starter-pack/$idPreset');
    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorMsg = ApiClient.extractErrorMessage(
        response,
        'No se pudo eliminar el producto del Preset Starter Pack',
      );
      throw Exception(errorMsg);
    }
  }

  /// Restablecer el Preset Global a los valores oficiales de fábrica (Exclusivo Superadmin)
  Future<List<StarterPackPresetItem>> restablecerStarterPackPreset() async {
    final response = await _client.post(
      '/superadmin/starter-pack/restablecer',
      {},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => StarterPackPresetItem.fromJson(json)).toList();
    }
    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo restablecer el Preset Starter Pack a valores de fábrica',
    );
    throw Exception(errorMsg);
  }

  // ===========================================================================
  // SUGERENCIAS DE PRECIOS Y CATÁLOGO SUPERADMIN ➔ BODEGAS
  // ===========================================================================

  /// Difundir sugerencia de precio/datos a bodegas existentes (Exclusivo Superadmin)
  Future<int> difundirSugerenciaPrecio(Map<String, dynamic> data) async {
    final response = await _client.post('/superadmin/sugerencias-precio', data);
    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return (json['bodegasNotificadas'] as num?)?.toInt() ?? 0;
    }
    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo difundir la sugerencia a las bodegas',
    );
    throw Exception(errorMsg);
  }

  /// Consultar cuántas bodegas activas tienen un producto por código de barras
  Future<int> contarBodegasConProducto(String codigoBarras) async {
    try {
      final clean = Uri.encodeComponent(codigoBarras.trim());
      final response = await _client.get(
        '/superadmin/sugerencias-precio/conteo-bodegas?codigoBarras=$clean',
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        return (json['bodegasConProducto'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  /// Listar sugerencias recibidas para la bodega autenticada
  Future<List<SugerenciaPrecioItem>> listarMisSugerenciasPrecio({
    String estado = 'PENDIENTE',
  }) async {
    try {
      final response = await _client.get(
        '/bodegas/mis-sugerencias-precio?estado=$estado',
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => SugerenciaPrecioItem.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Conteo de sugerencias de precios pendientes para la bodega actual
  Future<int> contarMisSugerenciasPendientes() async {
    try {
      final response = await _client.get(
        '/bodegas/mis-sugerencias-precio/conteo',
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        return (json['pendientes'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  /// Aceptar sugerencia de precio para la bodega actual
  Future<SugerenciaPrecioItem> aceptarSugerenciaPrecio(int idSugerencia) async {
    final response = await _client.put(
      '/bodegas/mis-sugerencias-precio/$idSugerencia/aceptar',
      {},
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return SugerenciaPrecioItem.fromJson(json);
    }
    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo aceptar la sugerencia',
    );
    throw Exception(errorMsg);
  }

  /// Rechazar sugerencia de precio para la bodega actual
  Future<SugerenciaPrecioItem> rechazarSugerenciaPrecio(
    int idSugerencia,
  ) async {
    final response = await _client.put(
      '/bodegas/mis-sugerencias-precio/$idSugerencia/rechazar',
      {},
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return SugerenciaPrecioItem.fromJson(json);
    }
    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo rechazar la sugerencia',
    );
    throw Exception(errorMsg);
  }

  /// Aceptar todas las sugerencias pendientes para la bodega actual
  Future<int> aceptarTodasSugerenciasPrecio() async {
    final response = await _client.put(
      '/bodegas/mis-sugerencias-precio/aceptar-todas',
      {},
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return (json['totalAceptadas'] as num?)?.toInt() ?? 0;
    }
    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudieron aceptar las sugerencias',
    );
    throw Exception(errorMsg);
  }

  /// Rechazar todas las sugerencias pendientes para la bodega actual
  Future<int> rechazarTodasSugerenciasPrecio() async {
    final response = await _client.put(
      '/bodegas/mis-sugerencias-precio/rechazar-todas',
      {},
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return (json['totalRechazadas'] as num?)?.toInt() ?? 0;
    }
    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudieron rechazar las sugerencias',
    );
    throw Exception(errorMsg);
  }

  /// Listar historial de sugerencias emitidas para la consola SuperAdmin
  Future<List<SugerenciaPrecioItem>> listarSugerenciasSuperadmin({
    String? estado,
  }) async {
    try {
      final query = (estado != null && estado.isNotEmpty && estado != 'TODOS')
          ? '?estado=$estado'
          : '';
      final response = await _client.get(
        '/superadmin/sugerencias-precio$query',
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => SugerenciaPrecioItem.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Estadísticas agregadas de sugerencias de precios (Exclusivo Superadmin)
  Future<Map<String, dynamic>> obtenerEstadisticasSugerencias() async {
    try {
      final response = await _client.get(
        '/superadmin/sugerencias-precio/estadisticas',
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  /// Monitor Financiero SaaS: MRR, bodegas por vencer y enlaces directos de cobranza por WhatsApp
  Future<Map<String, dynamic>> obtenerMonitorFinancieroSaaS() async {
    try {
      final response = await _client.get('/bodegas/finanzas-saas');
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  /// Configurar o restablecer el color de marca de cualquier bodega (Exclusivo Superadmin)
  Future<BodegaInfo> cambiarColorBodegaSuperadmin({
    required int idBodega,
    required String colorPrimario,
  }) async {
    final clean = Uri.encodeQueryComponent(colorPrimario.trim());
    final response = await _client.put(
      '/bodegas/$idBodega/color?colorPrimario=$clean',
      {},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return BodegaInfo.fromJson(data);
    }
    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo actualizar el color de la bodega',
    );
    throw Exception(errorMsg);
  }

  /// Obtiene el monitor y semáforo fiscal del Nuevo RUS (ventas y compras del mes vs límites S/ 5,000 y S/ 8,000)
  Future<ResumenNuevoRus?> obtenerMonitorNuevoRus({int? anio, int? mes}) async {
    try {
      final queryParams = <String, String>{};
      if (anio != null) queryParams['anio'] = anio.toString();
      if (mes != null) queryParams['mes'] = mes.toString();
      final uri = Uri(
        path: '/bodegas/nuevo-rus/monitor',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      ).toString();

      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return ResumenNuevoRus.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Actualiza el régimen tributario de la bodega ('NUEVO_RUS' o 'MYPE_TRIBUTARIO' / 'REGIMEN_GENERAL')
  Future<BodegaInfo> actualizarRegimenTributario(String regimen) async {
    final response = await _client.put(
      '/bodegas/regimen-tributario?regimen=$regimen',
      {},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final info = BodegaInfo.fromJson(data);
      _actualizarCacheLocal(info);
      await SecureStorageService.write(
        'regimen_tributario',
        info.regimenTributario,
      );
      return info;
    }
    final errorMsg = ApiClient.extractErrorMessage(
      response,
      'No se pudo actualizar el régimen tributario',
    );
    throw Exception(errorMsg);
  }
}

class ResumenNuevoRus {
  final int anio;
  final int mes;
  final String periodoNombre;
  final bool esNuevoRus;
  final String regimenTributario;
  final double totalVentasMes;
  final double totalComprasMes;
  final double montoDeterminante;
  final String categoriaActual;
  final String categoriaNombre;
  final double cuotaMensualEstimada;
  final double limiteCat1;
  final double limiteCat2;
  final double restanteCat1;
  final double restanteCat2;
  final double porcentajeCat1;
  final double porcentajeCat2;
  final String estadoSemaforo;
  final String mensajeDiagnostico;
  final String? advertencia;
  final String? sugerenciaPagoSunat;

  ResumenNuevoRus({
    required this.anio,
    required this.mes,
    required this.periodoNombre,
    required this.esNuevoRus,
    required this.regimenTributario,
    required this.totalVentasMes,
    required this.totalComprasMes,
    required this.montoDeterminante,
    required this.categoriaActual,
    required this.categoriaNombre,
    required this.cuotaMensualEstimada,
    required this.limiteCat1,
    required this.limiteCat2,
    required this.restanteCat1,
    required this.restanteCat2,
    required this.porcentajeCat1,
    required this.porcentajeCat2,
    required this.estadoSemaforo,
    required this.mensajeDiagnostico,
    this.advertencia,
    this.sugerenciaPagoSunat,
  });

  factory ResumenNuevoRus.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    return ResumenNuevoRus(
      anio: json['anio'] as int? ?? DateTime.now().year,
      mes: json['mes'] as int? ?? DateTime.now().month,
      periodoNombre: json['periodoNombre'] ?? '',
      esNuevoRus: json['esNuevoRus'] == true,
      regimenTributario: json['regimenTributario'] ?? 'NUEVO_RUS',
      totalVentasMes: parseDouble(json['totalVentasMes']),
      totalComprasMes: parseDouble(json['totalComprasMes']),
      montoDeterminante: parseDouble(json['montoDeterminante']),
      categoriaActual: json['categoriaActual'] ?? 'CATEGORIA_1',
      categoriaNombre: json['categoriaNombre'] ?? 'Categoría 1',
      cuotaMensualEstimada: parseDouble(json['cuotaMensualEstimada']),
      limiteCat1: parseDouble(json['limiteCat1'] ?? 5000),
      limiteCat2: parseDouble(json['limiteCat2'] ?? 8000),
      restanteCat1: parseDouble(json['restanteCat1']),
      restanteCat2: parseDouble(json['restanteCat2']),
      porcentajeCat1: parseDouble(json['porcentajeCat1']),
      porcentajeCat2: parseDouble(json['porcentajeCat2']),
      estadoSemaforo: json['estadoSemaforo'] ?? 'VERDE',
      mensajeDiagnostico: json['mensajeDiagnostico'] ?? '',
      advertencia: json['advertencia'],
      sugerenciaPagoSunat: json['sugerenciaPagoSunat'],
    );
  }
}

class PagoSuscripcionItem {
  final int idPago;
  final int? idBodega;
  final String? nombreBodega;
  final String codigoOperacion;
  final String billetera;
  final String plan;
  final double monto;
  final String? fechaPago;
  final String? usuarioRegistro;
  final String estado;

  PagoSuscripcionItem({
    required this.idPago,
    this.idBodega,
    this.nombreBodega,
    required this.codigoOperacion,
    required this.billetera,
    required this.plan,
    required this.monto,
    this.fechaPago,
    this.usuarioRegistro,
    required this.estado,
  });

  factory PagoSuscripcionItem.fromJson(Map<String, dynamic> json) {
    return PagoSuscripcionItem(
      idPago: json['idPago'] is int
          ? json['idPago']
          : int.parse(json['idPago'].toString()),
      idBodega: json['idBodega'],
      nombreBodega: json['nombreBodega'],
      codigoOperacion: json['codigoOperacion'] ?? '',
      billetera: json['billetera'] ?? '',
      plan: json['plan'] ?? 'PRO',
      monto: json['monto'] != null
          ? (json['monto'] is num
                ? (json['monto'] as num).toDouble()
                : double.tryParse(json['monto'].toString()) ?? 0.0)
          : 0.0,
      fechaPago: json['fechaPago'],
      usuarioRegistro: json['usuarioRegistro'],
      estado: json['estado'] ?? 'CONFIRMADO',
    );
  }
}

class StarterPackPresetItem {
  final int idPreset;
  final String codigoBarras;
  final String nombre;
  final String? marca;
  final String categoria;
  final double precioVenta;
  final double precioCosto;
  final String? imagenUrl;
  final bool activo;

  StarterPackPresetItem({
    required this.idPreset,
    required this.codigoBarras,
    required this.nombre,
    this.marca,
    required this.categoria,
    required this.precioVenta,
    required this.precioCosto,
    this.imagenUrl,
    required this.activo,
  });

  factory StarterPackPresetItem.fromJson(Map<String, dynamic> json) {
    return StarterPackPresetItem(
      idPreset: json['idPreset'] is int
          ? json['idPreset']
          : int.parse(json['idPreset']?.toString() ?? '0'),
      codigoBarras: json['codigoBarras']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      marca: json['marca']?.toString(),
      categoria: json['categoria']?.toString() ?? 'GENERAL',
      precioVenta: json['precioVenta'] != null
          ? (json['precioVenta'] is num
                ? (json['precioVenta'] as num).toDouble()
                : double.tryParse(json['precioVenta'].toString()) ?? 0.0)
          : 0.0,
      precioCosto: json['precioCosto'] != null
          ? (json['precioCosto'] is num
                ? (json['precioCosto'] as num).toDouble()
                : double.tryParse(json['precioCosto'].toString()) ?? 0.0)
          : 0.0,
      imagenUrl: json['imagenUrl']?.toString(),
      activo: json['activo'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idPreset': idPreset,
      'codigoBarras': codigoBarras,
      'nombre': nombre,
      'marca': marca,
      'categoria': categoria,
      'precioVenta': precioVenta,
      'precioCosto': precioCosto,
      'imagenUrl': imagenUrl,
      'activo': activo,
    };
  }
}

class SugerenciaPrecioItem {
  final int idSugerencia;
  final int idBodega;
  final String? nombreBodega;
  final int idProducto;
  final String codigoBarras;
  final String nombreActual;
  final String? nombreSugerido;
  final String? marcaActual;
  final String? marcaSugerida;
  final double precioVentaActual;
  final double precioVentaSugerido;
  final double? precioCostoActual;
  final double? precioCostoSugerido;
  final String? imagenUrl;
  final String? motivo;
  final String estado;
  final String? fechaCreacion;
  final String? fechaResolucion;
  final String? usuarioResolucion;

  SugerenciaPrecioItem({
    required this.idSugerencia,
    required this.idBodega,
    this.nombreBodega,
    required this.idProducto,
    required this.codigoBarras,
    required this.nombreActual,
    this.nombreSugerido,
    this.marcaActual,
    this.marcaSugerida,
    required this.precioVentaActual,
    required this.precioVentaSugerido,
    this.precioCostoActual,
    this.precioCostoSugerido,
    this.imagenUrl,
    this.motivo,
    required this.estado,
    this.fechaCreacion,
    this.fechaResolucion,
    this.usuarioResolucion,
  });

  factory SugerenciaPrecioItem.fromJson(Map<String, dynamic> json) {
    double? parseD(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return SugerenciaPrecioItem(
      idSugerencia: json['idSugerencia'] is int
          ? json['idSugerencia']
          : int.parse(json['idSugerencia']?.toString() ?? '0'),
      idBodega: json['idBodega'] is int
          ? json['idBodega']
          : int.parse(json['idBodega']?.toString() ?? '0'),
      nombreBodega: json['nombreBodega']?.toString(),
      idProducto: json['idProducto'] is int
          ? json['idProducto']
          : int.parse(json['idProducto']?.toString() ?? '0'),
      codigoBarras: json['codigoBarras']?.toString() ?? '',
      nombreActual: json['nombreActual']?.toString() ?? '',
      nombreSugerido: json['nombreSugerido']?.toString(),
      marcaActual: json['marcaActual']?.toString(),
      marcaSugerida: json['marcaSugerida']?.toString(),
      precioVentaActual: parseD(json['precioVentaActual']) ?? 0.0,
      precioVentaSugerido: parseD(json['precioVentaSugerido']) ?? 0.0,
      precioCostoActual: parseD(json['precioCostoActual']),
      precioCostoSugerido: parseD(json['precioCostoSugerido']),
      imagenUrl: json['imagenUrl']?.toString(),
      motivo: json['motivo']?.toString(),
      estado: json['estado']?.toString() ?? 'PENDIENTE',
      fechaCreacion: json['fechaCreacion']?.toString(),
      fechaResolucion: json['fechaResolucion']?.toString(),
      usuarioResolucion: json['usuarioResolucion']?.toString(),
    );
  }
}
