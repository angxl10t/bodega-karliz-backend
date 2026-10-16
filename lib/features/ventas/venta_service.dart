import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/api_client.dart';
import '../productos/producto_service.dart';
import 'venta_model.dart';

class VentaService {
  final ApiClient _apiClient = ApiClient();

  /// Notificador reactivo para sincronizar las pantallas de Caja y Ventas
  /// en tiempo real cada vez que se registre o anule una venta.
  static final ValueNotifier<int> ventasRevision = ValueNotifier<int>(0);

  static void notifyVentasChanged() {
    ventasRevision.value++;
  }

  /// Registra la venta. Retorna null si fue exitosa, o el mensaje de error si falló.
  Future<String?> registrarVenta(VentaEnvio venta) async {
    try {
      final response = await _apiClient.post('/ventas', venta.toJson());
      if (response.statusCode == 201 || response.statusCode == 200) {
        ProductoService.invalidateCache();
        notifyVentasChanged();
        return null; // Éxito
      }
      try {
        final errData = jsonDecode(utf8.decode(response.bodyBytes));
        if (errData is Map && errData.containsKey('error')) {
          return errData['error'].toString();
        }
      } catch (_) {}
      return 'Error ${response.statusCode} al procesar la venta en el servidor.';
    } catch (e) {
      return 'Error de conexión con el servidor. Verifica tu conexión a internet.';
    }
  }

  Future<List<VentaRegistro>> getVentas() async {
    try {
      final response = await _apiClient.get('/ventas');
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((json) => VentaRegistro.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<CierreCaja?> getCierreCajaHoy() async {
    try {
      final response = await _apiClient.get('/ventas/caja-hoy');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return CierreCaja.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<CierreCaja?> getCierreCajaPorFecha(DateTime fecha) async {
    try {
      final fechaStr =
          "${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}";
      final response = await _apiClient.get('/ventas/caja?fecha=$fechaStr');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return CierreCaja.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<CierreCaja>> getHistorialCierres({int dias = 30}) async {
    try {
      final response = await _apiClient.get('/ventas/caja-historial?dias=$dias');
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((json) => CierreCaja.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<({bool ok, String? error})> anularVentaConDetalle(int idVenta, {String? motivo}) async {
    try {
      final query = motivo != null && motivo.trim().isNotEmpty
          ? '?motivo=${Uri.encodeComponent(motivo.trim())}'
          : '';
      final response = await _apiClient.delete('/ventas/$idVenta$query');
      if (response.statusCode == 204 || response.statusCode == 200) {
        ProductoService.invalidateCache();
        notifyVentasChanged();
        return (ok: true, error: null);
      }
      try {
        final errData = jsonDecode(utf8.decode(response.bodyBytes));
        if (errData is Map && errData.containsKey('error')) {
          return (ok: false, error: errData['error'].toString());
        }
      } catch (_) {}
      return (ok: false, error: 'Error ${response.statusCode} al anular la venta.');
    } catch (e) {
      return (ok: false, error: 'Error de conexión con el servidor.');
    }
  }

  Future<bool> anularVenta(int idVenta, {String? motivo}) async {
    final res = await anularVentaConDetalle(idVenta, motivo: motivo);
    return res.ok;
  }
}
