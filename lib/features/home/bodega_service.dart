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

    try {
      final err = jsonDecode(utf8.decode(response.bodyBytes));
      if (err is Map && err.containsKey('error')) {
        throw Exception(err['error']);
      }
    } catch (e) {
      if (e is! FormatException && !e.toString().contains('error')) rethrow;
    }

    throw Exception('No se pudo guardar la configuración de la tienda.');
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

    try {
      final err = jsonDecode(utf8.decode(response.bodyBytes));
      if (err is Map && err.containsKey('error')) {
        throw Exception(err['error']);
      }
    } catch (e) {
      if (e is! FormatException && !e.toString().contains('error')) rethrow;
    }

    throw Exception('No se pudo registrar el pago de la suscripción.');
  }

  /// Solución 2: Configurar y activar el Módulo SUNAT (Exclusivo Administrador)
  Future<BodegaInfo> actualizarConfiguracionSunat({
    required bool activa,
    String? proveedor,
    String? rucEmisor,
    String? usuarioSol,
    String? tokenApi,
    String? serieBoleta,
    String? serieFactura,
  }) async {
    final body = <String, dynamic>{
      'facturacionSunatActiva': activa,
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
      return BodegaInfo.fromJson(data);
    }

    try {
      final err = jsonDecode(utf8.decode(response.bodyBytes));
      if (err is Map && err.containsKey('error')) {
        throw Exception(err['error']);
      }
    } catch (e) {
      if (e is! FormatException && !e.toString().contains('error')) rethrow;
    }

    throw Exception('No se pudo actualizar la configuración de SUNAT.');
  }
}
