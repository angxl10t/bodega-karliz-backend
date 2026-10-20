import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/api_client.dart';
import '../productos/producto_service.dart';
import 'venta_model.dart';

class RegistroVentaResult {
  final bool success;
  final String? errorMessage;
  final VentaRegistro? venta;

  RegistroVentaResult({required this.success, this.errorMessage, this.venta});
}

class VentaService {
  final ApiClient _apiClient = ApiClient();

  /// Notificador reactivo para sincronizar las pantallas de Caja y Ventas
  /// en tiempo real cada vez que se registre o anule una venta.
  static final ValueNotifier<int> ventasRevision = ValueNotifier<int>(0);

  static void notifyVentasChanged() {
    ventasRevision.value++;
  }

  /// Registra la venta y retorna el resultado detallado con el comprobante generado (Boleta/Factura).
  Future<RegistroVentaResult> registrarVentaCompleta(VentaEnvio venta) async {
    try {
      final response = await _apiClient.post('/ventas', venta.toJson());
      if (response.statusCode == 201 || response.statusCode == 200) {
        ProductoService.invalidateCache();
        notifyVentasChanged();
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return RegistroVentaResult(success: true, venta: VentaRegistro.fromJson(data));
      }
      final errorMsg = ApiClient.extractErrorMessage(response, 'Error al procesar la venta en el servidor');
      return RegistroVentaResult(success: false, errorMessage: errorMsg);
    } catch (e) {
      return RegistroVentaResult(success: false, errorMessage: 'Error de conexión con el servidor. Verifica tu conexión a internet.');
    }
  }

  /// Registra la venta. Retorna null si fue exitosa, o el mensaje de error si falló.
  Future<String?> registrarVenta(VentaEnvio venta) async {
    final res = await registrarVentaCompleta(venta);
    return res.success ? null : res.errorMessage;
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
      final errorMsg = ApiClient.extractErrorMessage(response, 'Error al anular la venta');
      return (ok: false, error: errorMsg);
    } catch (e) {
      return (ok: false, error: 'Error de conexión con el servidor.');
    }
  }

  Future<bool> anularVenta(int idVenta, {String? motivo}) async {
    final res = await anularVentaConDetalle(idVenta, motivo: motivo);
    return res.ok;
  }

  /// Reintenta el envío de un comprobante electrónico pendiente a SUNAT
  Future<RegistroVentaResult> reintentarSunat(int idVenta) async {
    try {
      final response = await _apiClient.post('/ventas/$idVenta/reintentar-sunat', {});
      if (response.statusCode == 200) {
        notifyVentasChanged();
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return RegistroVentaResult(success: true, venta: VentaRegistro.fromJson(data));
      }
      final errorMsg = ApiClient.extractErrorMessage(response, 'Error al reintentar envío a SUNAT');
      return RegistroVentaResult(success: false, errorMessage: errorMsg);
    } catch (e) {
      return RegistroVentaResult(success: false, errorMessage: 'Error de conexión con el servidor al reintentar envío.');
    }
  }

  /// Obtiene el arqueo completo con fondo inicial, ventas y egresos de caja chica
  Future<CierreCaja?> getArqueoCompleto(DateTime fecha) async {
    try {
      final fechaStr =
          "${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}";
      final response = await _apiClient.get('/caja/arqueo?fecha=$fechaStr');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return CierreCaja.fromJson(data);
      }
      return await getCierreCajaPorFecha(fecha);
    } catch (_) {
      return await getCierreCajaPorFecha(fecha);
    }
  }

  /// Registra un nuevo egreso menor de caja chica
  Future<bool> registrarEgreso({
    required double monto,
    required String motivo,
    String categoriaGasto = 'VARIOS',
  }) async {
    try {
      final body = {
        'monto': monto,
        'motivo': motivo,
        'categoriaGasto': categoriaGasto,
      };
      final response = await _apiClient.post('/caja/egresos', body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        notifyVentasChanged();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Anula un egreso de caja chica existente
  Future<bool> anularEgreso(int idEgreso, {String? motivo}) async {
    try {
      final url = motivo != null && motivo.isNotEmpty
          ? '/caja/egresos/$idEgreso?motivo=${Uri.encodeComponent(motivo)}'
          : '/caja/egresos/$idEgreso';
      final response = await _apiClient.delete(url);
      if (response.statusCode == 204 || response.statusCode == 200) {
        notifyVentasChanged();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Registra o actualiza el fondo inicial (sencillo) de la caja
  Future<bool> registrarFondoInicial(double monto, {DateTime? fecha}) async {
    try {
      final targetFecha = fecha ?? DateTime.now();
      final fechaStr =
          "${targetFecha.year.toString().padLeft(4, '0')}-${targetFecha.month.toString().padLeft(2, '0')}-${targetFecha.day.toString().padLeft(2, '0')}";
      final body = {
        'montoInicial': monto,
        'fecha': fechaStr,
      };
      final response = await _apiClient.post('/caja/fondo-inicial', body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        notifyVentasChanged();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
