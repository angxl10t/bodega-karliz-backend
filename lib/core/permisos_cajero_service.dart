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
  static const String _userPrefPrefix = 'cajaya_permisos_cajero_usuario_';

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

  static Future<String> _resolveBodegaId(String? bodegaId) async {
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
    return id.isNotEmpty ? id : '1';
  }

  static String _userKey(String bodegaId, String username) {
    return '$_userPrefPrefix${bodegaId}_${username.trim().toLowerCase()}';
  }

  static String _bodegaKey(String bodegaId) {
    return '$_prefPrefix$bodegaId';
  }

  /// Carga los permisos activos. Si el usuario actual o especificado tiene override individual, se aplica;
  /// caso contrario se hereda la plantilla general de la bodega.
  static Future<PermisosCajero> obtenerPermisos({
    String? bodegaId,
    String? username,
    bool forceRefresh = false,
  }) async {
    if (_inicializado &&
        bodegaId == null &&
        username == null &&
        !forceRefresh) {
      return _cachedPermisos;
    }

    final id = await _resolveBodegaId(bodegaId);
    String uname = username ?? '';
    if (uname.isEmpty) {
      try {
        uname = await AuthService().getUsername();
      } catch (_) {}
    }

    // 1. Si hay usuario especificado o en sesión, verificar si tiene override individual
    if (uname.isNotEmpty) {
      final userPermisos = await obtenerPermisosUsuario(uname, bodegaId: id);
      if (userPermisos != null) {
        _cachedPermisos = userPermisos;
        _inicializado = true;
        return _cachedPermisos;
      }
    }

    // 2. Si no tiene override, cargar la política general de la bodega
    final key = _bodegaKey(id);

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

  /// Guarda los permisos generales de la bodega (plantilla base para cajeros)
  static Future<void> guardarPermisos(
    PermisosCajero permisos, {
    String? bodegaId,
  }) async {
    final id = await _resolveBodegaId(bodegaId);
    final key = _bodegaKey(id);
    final raw = jsonEncode(permisos.toJson());

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, raw);
    } catch (_) {}

    try {
      await SecureStorageService.write(key, raw);
    } catch (_) {}

    // Si el usuario actual no tiene override individual, actualizar en memoria
    String currentUname = '';
    try {
      currentUname = await AuthService().getUsername();
    } catch (_) {}

    if (currentUname.isEmpty ||
        !(await tienePermisosPersonalizados(currentUname, bodegaId: id))) {
      _cachedPermisos = permisos;
    }
    _inicializado = true;
    permisosRevision.value++;
  }

  /// Consulta si un cajero específico tiene permisos individuales personalizados (override)
  static Future<bool> tienePermisosPersonalizados(
    String username, {
    String? bodegaId,
  }) async {
    if (username.trim().isEmpty) return false;
    final permisos = await obtenerPermisosUsuario(username, bodegaId: bodegaId);
    return permisos != null;
  }

  /// Obtiene los permisos individuales de un usuario específico. Retorna null si no tiene override y usa los de la tienda.
  static Future<PermisosCajero?> obtenerPermisosUsuario(
    String username, {
    String? bodegaId,
  }) async {
    if (username.trim().isEmpty) return null;
    final id = await _resolveBodegaId(bodegaId);
    final key = _userKey(id, username);

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return PermisosCajero.fromJson(decoded);
      }
    } catch (_) {}

    try {
      final raw = await SecureStorageService.read(key);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return PermisosCajero.fromJson(decoded);
      }
    } catch (_) {}

    return null;
  }

  /// Guarda o actualiza los permisos individuales de un cajero específico
  static Future<void> guardarPermisosUsuario(
    String username,
    PermisosCajero permisos, {
    String? bodegaId,
  }) async {
    if (username.trim().isEmpty) return;
    final id = await _resolveBodegaId(bodegaId);
    final key = _userKey(id, username);
    final raw = jsonEncode(permisos.toJson());

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, raw);
    } catch (_) {}

    try {
      await SecureStorageService.write(key, raw);
    } catch (_) {}

    // Si el usuario modificado es el usuario actualmente en sesión, actualizar en memoria
    String currentUname = '';
    try {
      currentUname = await AuthService().getUsername();
    } catch (_) {}

    if (currentUname.isNotEmpty &&
        currentUname.trim().toLowerCase() == username.trim().toLowerCase()) {
      _cachedPermisos = permisos;
    }
    permisosRevision.value++;
  }

  /// Elimina los permisos individuales de un cajero para que vuelva a heredar los de la tienda
  static Future<void> eliminarPermisosUsuario(
    String username, {
    String? bodegaId,
  }) async {
    if (username.trim().isEmpty) return;
    final id = await _resolveBodegaId(bodegaId);
    final key = _userKey(id, username);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}

    try {
      await SecureStorageService.delete(key);
    } catch (_) {}

    // Si el usuario afectado es el usuario en sesión, recargar los permisos generales
    String currentUname = '';
    try {
      currentUname = await AuthService().getUsername();
    } catch (_) {}

    if (currentUname.isNotEmpty &&
        currentUname.trim().toLowerCase() == username.trim().toLowerCase()) {
      await obtenerPermisos(bodegaId: id, forceRefresh: true);
    }
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
