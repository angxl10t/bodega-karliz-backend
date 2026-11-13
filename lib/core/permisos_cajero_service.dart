import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/auth/auth_service.dart';
import 'secure_storage_service.dart';

class PermisosCajero {
  /// Permite ver el costo de compra (precioCosto) y el margen de ganancia en catálogo y formularios
  final bool verCostosYMargen;

  /// Permite aplicar descuentos manuales / de cortesía en el carrito de ventas
  final bool aplicarDescuentosManuales;

  /// Permite anular ventas o eliminar ítems del carrito sin requerir PIN de Administrador
  final bool anularVentasSinPin;

  /// Permite crear productos o modificar precios de venta en inventario sin PIN
  final bool modificarPreciosVenta;

  /// Permite acceder a pantallas de Inteligencia de Negocios (BI) y métricas de utilidad neta
  final bool verReportesFinanzas;

  const PermisosCajero({
    this.verCostosYMargen = false,
    this.aplicarDescuentosManuales = true,
    this.anularVentasSinPin = false,
    this.modificarPreciosVenta = false,
    this.verReportesFinanzas = false,
  });

  /// Preset: Máxima Seguridad (Solo cobrar precios exactos, todo lo demás bloqueado)
  factory PermisosCajero.seguridadMaxima() => const PermisosCajero(
        verCostosYMargen: false,
        aplicarDescuentosManuales: false,
        anularVentasSinPin: false,
        modificarPreciosVenta: false,
        verReportesFinanzas: false,
      );

  /// Preset: Estándar Recomendado (Permite aplicar descuentos, pero protege costos y anulaciones)
  factory PermisosCajero.estandarRecomendado() => const PermisosCajero(
        verCostosYMargen: false,
        aplicarDescuentosManuales: true,
        anularVentasSinPin: false,
        modificarPreciosVenta: false,
        verReportesFinanzas: false,
      );

  /// Preset: Cajero de Confianza / Encargado (Permite ver costos y anular)
  factory PermisosCajero.cajeroEncargado() => const PermisosCajero(
        verCostosYMargen: true,
        aplicarDescuentosManuales: true,
        anularVentasSinPin: true,
        modificarPreciosVenta: true,
        verReportesFinanzas: false,
      );

  Map<String, dynamic> toJson() => {
        'verCostosYMargen': verCostosYMargen,
        'aplicarDescuentosManuales': aplicarDescuentosManuales,
        'anularVentasSinPin': anularVentasSinPin,
        'modificarPreciosVenta': modificarPreciosVenta,
        'verReportesFinanzas': verReportesFinanzas,
      };

  factory PermisosCajero.fromJson(Map<String, dynamic> json) {
    return PermisosCajero(
      verCostosYMargen: json['verCostosYMargen'] == true,
      aplicarDescuentosManuales: json['aplicarDescuentosManuales'] ?? true,
      anularVentasSinPin: json['anularVentasSinPin'] == true,
      modificarPreciosVenta: json['modificarPreciosVenta'] == true,
      verReportesFinanzas: json['verReportesFinanzas'] == true,
    );
  }

  PermisosCajero copyWith({
    bool? verCostosYMargen,
    bool? aplicarDescuentosManuales,
    bool? anularVentasSinPin,
    bool? modificarPreciosVenta,
    bool? verReportesFinanzas,
  }) {
    return PermisosCajero(
      verCostosYMargen: verCostosYMargen ?? this.verCostosYMargen,
      aplicarDescuentosManuales:
          aplicarDescuentosManuales ?? this.aplicarDescuentosManuales,
      anularVentasSinPin: anularVentasSinPin ?? this.anularVentasSinPin,
      modificarPreciosVenta:
          modificarPreciosVenta ?? this.modificarPreciosVenta,
      verReportesFinanzas: verReportesFinanzas ?? this.verReportesFinanzas,
    );
  }
}

class PermisosCajeroService {
  static const String _prefPrefix = 'cajaya_permisos_cajero_bodega_';

  static PermisosCajero _cachedPermisos = const PermisosCajero();
  static bool _inicializado = false;

  /// Notificador para que los widgets se redibujen automáticamente cuando cambian los permisos
  static final ValueNotifier<int> permisosRevision = ValueNotifier<int>(0);

  static PermisosCajero get currentPermisos => _cachedPermisos;

  /// Si el usuario actual es ADMIN o SUPERADMIN, tiene todos los permisos activos sin restricción
  static bool get esAdminOsuperior => AuthService.esAdmin;

  /// Consultas síncronas rápidas (evalúa rol de usuario + permiso granular):
  static bool get puedeVerCostos {
    if (esAdminOsuperior) return true;
    return _cachedPermisos.verCostosYMargen;
  }

  static bool get puedeAplicarDescuentos {
    if (esAdminOsuperior) return true;
    return _cachedPermisos.aplicarDescuentosManuales;
  }

  static bool get puedeAnularSinPin {
    if (esAdminOsuperior) return true;
    return _cachedPermisos.anularVentasSinPin;
  }

  static bool get puedeModificarPrecios {
    if (esAdminOsuperior) return true;
    return _cachedPermisos.modificarPreciosVenta;
  }

  static bool get puedeVerFinanzas {
    if (esAdminOsuperior) return true;
    return _cachedPermisos.verReportesFinanzas;
  }

  /// Carga los permisos desde almacenamiento seguro o SharedPreferences para la bodega actual
  static Future<PermisosCajero> obtenerPermisos({String? bodegaId}) async {
    if (_inicializado && bodegaId == null) {
      return _cachedPermisos;
    }

    String id = bodegaId ?? '';
    if (id.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        id = prefs.getString('id_bodega') ?? '';
      } catch (_) {}
    }
    if (id.isEmpty) {
      try {
        id = await AuthService().getIdBodega();
      } catch (_) {
        id = '1';
      }
    }

    final key = '$_prefPrefix$id';

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _cachedPermisos = PermisosCajero.fromJson(decoded);
        _inicializado = true;
        return _cachedPermisos;
      }
    } catch (_) {}

    try {
      final raw = await SecureStorageService.read(key);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _cachedPermisos = PermisosCajero.fromJson(decoded);
        _inicializado = true;
        return _cachedPermisos;
      }
    } catch (_) {}

    _cachedPermisos = const PermisosCajero();
    _inicializado = true;
    return _cachedPermisos;
  }

  /// Guarda los permisos para la bodega actual
  static Future<void> guardarPermisos(PermisosCajero permisos, {String? bodegaId}) async {
    String id = bodegaId ?? '';
    if (id.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        id = prefs.getString('id_bodega') ?? '';
      } catch (_) {}
    }
    if (id.isEmpty) {
      try {
        id = await AuthService().getIdBodega();
      } catch (_) {
        id = '1';
      }
    }

    final key = '$_prefPrefix$id';
    final raw = jsonEncode(permisos.toJson());

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, raw);
    } catch (_) {}

    try {
      await SecureStorageService.write(key, raw);
    } catch (_) {}

    _cachedPermisos = permisos;
    _inicializado = true;
    permisosRevision.value++;
  }

  /// Precarga síncrona en inicio de app o sesión
  static Future<void> inicializar() async {
    if (!_inicializado) {
      await obtenerPermisos();
    }
  }

  /// Reset de memoria en logout o cambio de bodega
  static void resetMemory() {
    _cachedPermisos = const PermisosCajero();
    _inicializado = false;
    permisosRevision.value++;
  }
}
