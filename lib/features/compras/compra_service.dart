import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/api_client.dart';
import '../productos/producto_service.dart';
import 'compra_model.dart';

class CompraService {
  final ApiClient _apiClient = ApiClient();

  /// Notificador reactivo para sincronizar compras y Kardex en tiempo real
  static final ValueNotifier<int> comprasRevision = ValueNotifier<int>(0);

  static void notifyComprasChanged() {
    comprasRevision.value++;
  }

  /// Registra la compra. Retorna null si fue exitosa, o el mensaje de error si falló.
  Future<String?> registrarCompra(CompraEnvio compra) async {
    try {
      final response = await _apiClient.post('/compras', compra.toJson());
      if (response.statusCode == 201 || response.statusCode == 200) {
        ProductoService.invalidateCache();
        notifyComprasChanged();
        return null; // Éxito
      }
      final errorMsg = ApiClient.extractErrorMessage(response, 'Error al procesar la compra en el servidor');
      return errorMsg;
    } catch (e) {
      return 'Error de conexión con el servidor. Verifica tu conexión a internet.';
    }
  }

  Future<List<CompraRegistro>> getCompras() async {
    try {
      final response = await _apiClient.get('/compras');
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((json) => CompraRegistro.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
