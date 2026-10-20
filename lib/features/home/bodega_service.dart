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
  final String? sunatProveedor;
  final String? sunatRucEmisor;
  final String? sunatUsuarioSol;
  final String? serieBoleta;
  final String? serieFactura;

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
    this.sunatProveedor,
    this.sunatRucEmisor,
    this.sunatUsuarioSol,
    this.serieBoleta,
    this.serieFactura,
  });

  factory BodegaInfo.fromJson(Map<String, dynamic> json) {
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
      regimenTributario: json['regimenTributario'] as String? ?? 'NUEVO_RUS',
      sunatProveedor: json['sunatProveedor'],
      sunatRucEmisor: json['sunatRucEmisor'],
      sunatUsuarioSol: json['sunatUsuarioSol'],
      serieBoleta: json['serieBoleta'],
      serieFactura: json['serieFactura'],
    );
  }
}

class BodegaService {
  final ApiClient _client = ApiClient();

  Future<BodegaInfo?> obtenerMiBodega() async {
    try {
      final response = await _client.get('/bodegas/mi-bodega');
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final info = BodegaInfo.fromJson(data);

        // Actualizar caché seguro local
        await SecureStorageService.write('nombre_bodega', info.nombreComercial);
        await SecureStorageService.write('plan_bodega', info.plan);
        await SecureStorageService.write('regimen_tributario', info.regimenTributario);
        await SecureStorageService.write('facturacion_sunat_activa', info.facturacionSunatActiva.toString());
        if (info.rucDni != null) await SecureStorageService.write('ruc_bodega', info.rucDni!);
        if (info.direccion != null) await SecureStorageService.write('direccion_bodega', info.direccion!);
        if (info.telefono != null) await SecureStorageService.write('telefono_bodega', info.telefono!);
        await SecureStorageService.write('color_primario', info.colorPrimario);
        if (info.lemaComercial != null) await SecureStorageService.write('lema_comercial', info.lemaComercial!);
        if (info.logoUrl != null) await SecureStorageService.write('logo_url', info.logoUrl!);

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

      await SecureStorageService.write('nombre_bodega', info.nombreComercial);
      if (info.rucDni != null) await SecureStorageService.write('ruc_bodega', info.rucDni!);
      if (info.direccion != null) await SecureStorageService.write('direccion_bodega', info.direccion!);
      if (info.telefono != null) await SecureStorageService.write('telefono_bodega', info.telefono!);
      await SecureStorageService.write('color_primario', info.colorPrimario);
      if (info.lemaComercial != null) await SecureStorageService.write('lema_comercial', info.lemaComercial!);
      if (info.logoUrl != null) await SecureStorageService.write('logo_url', info.logoUrl!);

      return info;
    }

    final errorMsg = ApiClient.extractErrorMessage(response, 'No se pudo guardar la configuración de la tienda');
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
      await SecureStorageService.write('plan_bodega', info.plan);
      return info;
    }

    final errorMsg = ApiClient.extractErrorMessage(response, 'No se pudo registrar el pago de la suscripción');
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

      await SecureStorageService.write('regimen_tributario', info.regimenTributario);
      await SecureStorageService.write('facturacion_sunat_activa', info.facturacionSunatActiva.toString());

      return info;
    }

    final errorMsg = ApiClient.extractErrorMessage(response, 'No se pudo actualizar la configuración de SUNAT');
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
    final response = await _client.put('/bodegas/$idBodega/estado?activo=$activo', {});
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return BodegaInfo.fromJson(data);
    }
    final errorMsg = ApiClient.extractErrorMessage(response, 'No se pudo cambiar el estado de la bodega');
    throw Exception(errorMsg);
  }

  /// Cambiar o extender el plan de una bodega (Exclusivo Superadmin)
  Future<BodegaInfo> cambiarPlanBodega(int idBodega, String plan, {int dias = 30}) async {
    final response = await _client.put('/bodegas/$idBodega/plan?plan=$plan&dias=$dias', {});
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return BodegaInfo.fromJson(data);
    }
    final errorMsg = ApiClient.extractErrorMessage(response, 'No se pudo actualizar el plan de la bodega');
    throw Exception(errorMsg);
  }

  /// Métricas consolidadas del SaaS (Exclusivo Superadmin)
  Future<Map<String, dynamic>> obtenerMetricasSistema() async {
    try {
      final response = await _client.get('/bodegas/metricas-sistema');
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  /// Monitoreo de salud y telemetría JVM del servidor
  Future<Map<String, dynamic>> obtenerHealthServidor() async {
    try {
      final response = await _client.get('/health');
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
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
    final errorMsg = ApiClient.extractErrorMessage(response, 'No se pudo crear la bodega');
    throw Exception(errorMsg);
  }

  /// Cambiar estado de un pago en el libro mayor de suscripciones (Superadmin)
  Future<PagoSuscripcionItem> cambiarEstadoPago(int idPago, String nuevoEstado) async {
    final response = await _client.put('/bodegas/pagos/$idPago/estado?estado=$nuevoEstado', {});
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return PagoSuscripcionItem.fromJson(data);
    }
    final errorMsg = ApiClient.extractErrorMessage(response, 'No se pudo actualizar el estado del pago');
    throw Exception(errorMsg);
  }

  /// Obtener comunicado global activo del SaaS
  Future<Map<String, dynamic>> obtenerAnuncioGlobal() async {
    try {
      final response = await _client.get('/bodegas/anuncio-global');
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  /// Publicar o actualizar comunicado global (Superadmin)
  Future<Map<String, dynamic>> publicarAnuncioGlobal(String mensaje, {String tipo = 'INFO'}) async {
    final response = await _client.post('/bodegas/anuncio-global', {
      'mensaje': mensaje,
      'tipo': tipo,
    });
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    }
    final errorMsg = ApiClient.extractErrorMessage(response, 'No se pudo publicar el anuncio');
    throw Exception(errorMsg);
  }

  /// Eliminar comunicado global (Superadmin)
  Future<void> eliminarAnuncioGlobal() async {
    final response = await _client.delete('/bodegas/anuncio-global');
    if (response.statusCode != 200) {
      final errorMsg = ApiClient.extractErrorMessage(response, 'No se pudo eliminar el anuncio');
      throw Exception(errorMsg);
    }
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
      idPago: json['idPago'] is int ? json['idPago'] : int.parse(json['idPago'].toString()),
      idBodega: json['idBodega'],
      nombreBodega: json['nombreBodega'],
      codigoOperacion: json['codigoOperacion'] ?? '',
      billetera: json['billetera'] ?? '',
      plan: json['plan'] ?? 'PRO',
      monto: json['monto'] != null
          ? (json['monto'] is num ? (json['monto'] as num).toDouble() : double.tryParse(json['monto'].toString()) ?? 0.0)
          : 0.0,
      fechaPago: json['fechaPago'],
      usuarioRegistro: json['usuarioRegistro'],
      estado: json['estado'] ?? 'CONFIRMADO',
    );
  }
}
