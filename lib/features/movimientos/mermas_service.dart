import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/secure_storage_service.dart';
import '../auth/auth_service.dart';
import '../productos/producto_model.dart';
import 'merma_model.dart';
import 'movimiento_service.dart';

class MermasService {
  static const String _defaultStorageKey = 'cajaya_mermas_historico_v1';
  static final ValueNotifier<int> mermasRevision = ValueNotifier<int>(0);
  static bool _sessionCleanupRegistered = false;

  static void _ensureSessionCleanupRegistered() {
    if (!_sessionCleanupRegistered) {
      _sessionCleanupRegistered = true;
      SecureStorageService.registerSessionCleanup(resetSession);
    }
  }

  static void resetSession() {
    mermasRevision.value = 0;
  }

  static Future<String> _getStorageKey() async {
    try {
      final idBodega = await SecureStorageService.read('id_bodega');
      if (idBodega != null && idBodega.trim().isNotEmpty) {
        return 'cajaya_mermas_historico_${idBodega.trim()}_v1';
      }
    } catch (_) {}
    return _defaultStorageKey;
  }

  final MovimientoService _movimientoService = MovimientoService();

  /// Registra una baja por merma o desmedro tanto en el Kardex/Backend como en el registro contable
  Future<bool> registrarMerma({
    required Producto producto,
    required double cantidad,
    required String motivo,
    required double costoUnitario,
    String observaciones = '',
  }) async {
    if (producto.idProducto == null || cantidad <= 0) return false;

    final usuario = await AuthService().getUsername();
    final costoTotal = cantidad * costoUnitario;

    final motivoKardex =
        '[${motivo.toUpperCase()}] Merma: $observaciones (Pérdida S/ ${costoTotal.toStringAsFixed(2)})';

    // 1. Descontar del inventario en backend / Kardex
    final ok = await _movimientoService.registrarAjuste(
      idProducto: producto.idProducto!,
      cantidad: cantidad,
      tipoAjuste: motivo.toUpperCase(),
      motivo: motivoKardex,
    );

    if (!ok) return false;

    // 2. Guardar en registro histórico de mermas
    final merma = MermaRegistro(
      idMerma: 'MRM-${DateTime.now().millisecondsSinceEpoch}',
      idProducto: producto.idProducto!,
      nombreProducto: producto.nombre,
      cantidad: cantidad,
      motivo: motivo.toUpperCase(),
      costoUnitario: costoUnitario,
      costoTotal: costoTotal,
      observaciones: observaciones,
      usuarioResponsable: usuario,
      fecha: DateTime.now(),
    );

    final lista = await obtenerMermas();
    lista.insert(0, merma);
    await _guardarLista(lista);

    mermasRevision.value++;
    return true;
  }

  /// Obtiene la lista completa de mermas registradas ordenadas cronológicamente
  Future<List<MermaRegistro>> obtenerMermas() async {
    _ensureSessionCleanupRegistered();
    try {
      final key = await _getStorageKey();
      String? raw = await SecureStorageService.read(key);
      if ((raw == null || raw.trim().isEmpty) && key != _defaultStorageKey) {
        raw = await SecureStorageService.read(_defaultStorageKey);
      }
      if (raw != null && raw.trim().isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        return decoded
            .map((j) => MermaRegistro.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _guardarLista(List<MermaRegistro> lista) async {
    _ensureSessionCleanupRegistered();
    try {
      final key = await _getStorageKey();
      final encoded = jsonEncode(lista.map((m) => m.toJson()).toList());
      await SecureStorageService.write(key, encoded);
    } catch (_) {}
  }

  /// Calcula las métricas del mes en curso para los paneles de control
  Future<Map<String, dynamic>> calcularKpisMes() async {
    final mermas = await obtenerMermas();
    final now = DateTime.now();

    final mermasMes = mermas
        .where((m) => m.fecha.year == now.year && m.fecha.month == now.month)
        .toList();

    double totalPerdidaSoles = 0.0;
    double totalUnidades = 0.0;
    final Map<String, int> porMotivo = {};

    for (final m in mermasMes) {
      totalPerdidaSoles += m.costoTotal;
      totalUnidades += m.cantidad;
      porMotivo[m.motivo] = (porMotivo[m.motivo] ?? 0) + 1;
    }

    String causaPrincipal = 'Ninguna';
    int maxOcurrencias = 0;
    porMotivo.forEach((k, v) {
      if (v > maxOcurrencias) {
        maxOcurrencias = v;
        causaPrincipal = k;
      }
    });

    return {
      'totalPerdidaSoles': totalPerdidaSoles,
      'totalUnidades': totalUnidades,
      'causaPrincipal': causaPrincipal,
      'conteoMes': mermasMes.length,
    };
  }
}
