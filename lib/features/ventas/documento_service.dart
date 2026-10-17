import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/api_constants.dart';
import '../../core/secure_storage_service.dart';
import 'documento_model.dart';

class DocumentoService {
  /// Consulta un DNI a través del backend BFF (RENIEC)
  Future<DniResponse?> consultarDni(String numero) async {
    final cleanDoc = numero.trim();
    if (cleanDoc.length != 8 || !RegExp(r'^[0-9]{8}$').hasMatch(cleanDoc)) {
      return null;
    }

    try {
      final token = await SecureStorageService.read('jwt_token');
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/v1/documentos/dni/$cleanDoc'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return DniResponse.fromJson(data);
      }
    } catch (_) {
      // En caso de corte de conexión, no interrumpir el flujo del POS
    }
    return DniResponse(
      numero: cleanDoc,
      nombreCompleto: '',
      encontrado: false,
      mensaje: 'No se pudo conectar con el servicio de consulta.',
    );
  }

  /// Consulta un RUC a través del backend BFF (SUNAT)
  Future<RucResponse?> consultarRuc(String numero) async {
    final cleanRuc = numero.trim();
    if (cleanRuc.length != 11 || !RegExp(r'^[0-9]{11}$').hasMatch(cleanRuc)) {
      return null;
    }

    try {
      final token = await SecureStorageService.read('jwt_token');
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/v1/documentos/ruc/$cleanRuc'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return RucResponse.fromJson(data);
      }
    } catch (_) {
      // En caso de corte de conexión, no interrumpir el flujo del POS
    }
    return RucResponse(
      numero: cleanRuc,
      razonSocial: '',
      estado: 'DESCONOCIDO',
      condicion: 'DESCONOCIDO',
      esActivo: true,
      esHabido: true,
      encontrado: false,
      mensaje: 'No se pudo conectar con el servicio de consulta SUNAT.',
    );
  }
}
