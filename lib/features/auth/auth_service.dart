import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/api_constants.dart';
import '../../core/secure_storage_service.dart';

class AuthResult {
  final bool success;
  final String? errorMessage;

  AuthResult({required this.success, this.errorMessage});
}

class AuthService {
  Future<AuthResult> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String token = data['token'];
        final String rol = data['rol'];

        // Almacenamiento seguro cifrado en hardware (AES-256 / Android Keystore)
        await SecureStorageService.write('jwt_token', token);
        await SecureStorageService.write('user_rol', rol);
        await SecureStorageService.write('username', username);
        if (data['idBodega'] != null) {
          await SecureStorageService.write('id_bodega', data['idBodega'].toString());
        }
        if (data['nombreBodega'] != null) {
          await SecureStorageService.write('nombre_bodega', data['nombreBodega']);
        }
        if (data['plan'] != null) {
          await SecureStorageService.write('plan_bodega', data['plan']);
        }
        if (data['ruc'] != null) {
          await SecureStorageService.write('ruc_bodega', data['ruc']);
        }
        if (data['direccion'] != null) {
          await SecureStorageService.write('direccion_bodega', data['direccion']);
        }
        if (data['telefono'] != null) {
          await SecureStorageService.write('telefono_bodega', data['telefono']);
        }
        if (data['colorPrimario'] != null) {
          await SecureStorageService.write('color_primario', data['colorPrimario']);
        }
        if (data['lemaComercial'] != null) {
          await SecureStorageService.write('lema_comercial', data['lemaComercial']);
        }
        if (data['logoUrl'] != null) {
          await SecureStorageService.write('logo_url', data['logoUrl']);
        }
        if (data['regimenTributario'] != null) {
          await SecureStorageService.write('regimen_tributario', data['regimenTributario']);
        }
        if (data['facturacionSunatActiva'] != null) {
          await SecureStorageService.write('facturacion_sunat_activa', data['facturacionSunatActiva'].toString());
        }
        return AuthResult(success: true); // Login exitoso
      }

      // Procesar mensaje específico de seguridad del backend (Rate Limiting 429, Desactivado 400, etc.)
      try {
        final errData = jsonDecode(utf8.decode(response.bodyBytes));
        if (errData is Map && errData.containsKey('error')) {
          return AuthResult(success: false, errorMessage: errData['error'].toString());
        }
      } catch (_) {}

      if (response.statusCode == 429) {
        return AuthResult(
          success: false,
          errorMessage: 'Demasiados intentos fallidos. Acceso bloqueado temporalmente por seguridad.',
        );
      }

      return AuthResult(success: false, errorMessage: 'Usuario o contraseña incorrectos');
    } catch (_) {
      return AuthResult(
        success: false,
        errorMessage: 'Error de conexión con el servidor. Verifica tu internet.',
      );
    }
  }

  Future<void> logout() async {
    await SecureStorageService.clearAuth();
  }

  Future<bool> isLoggedIn() async {
    final token = await SecureStorageService.read('jwt_token');
    if (token == null || token.trim().isEmpty) {
      return false;
    }
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        await SecureStorageService.clearAuth();
        return false;
      }
      final normalized = base64Url.normalize(parts[1]);
      final payloadStr = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(payloadStr);
      if (payload is Map && payload.containsKey('exp')) {
        final exp = payload['exp'];
        if (exp is int) {
          final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
          if (DateTime.now().isAfter(expDate)) {
            await SecureStorageService.clearAuth();
            return false;
          }
        }
      }
    } catch (_) {
      await SecureStorageService.clearAuth();
      return false;
    }
    return true;
  }

  Future<String> getUsername() async {
    return await SecureStorageService.read('username') ?? 'Usuario';
  }

  Future<String> getUserRole() async {
    return await SecureStorageService.read('user_rol') ?? 'CAJERO';
  }

  Future<String> getNombreBodega() async {
    return await SecureStorageService.read('nombre_bodega') ?? 'Bodega KARLIZ';
  }

  Future<String> getPlanBodega() async {
    return await SecureStorageService.read('plan_bodega') ?? 'PRO';
  }

  Future<String> getIdBodega() async {
    return await SecureStorageService.read('id_bodega') ?? '1';
  }

  Future<String> getRucBodega() async {
    return await SecureStorageService.read('ruc_bodega') ?? '';
  }

  Future<String> getDireccionBodega() async {
    return await SecureStorageService.read('direccion_bodega') ?? '';
  }

  Future<String> getTelefonoBodega() async {
    return await SecureStorageService.read('telefono_bodega') ?? '';
  }

  Future<String> getColorPrimario() async {
    return await SecureStorageService.read('color_primario') ?? '#2563EB';
  }

  Future<String> getLemaComercial() async {
    return await SecureStorageService.read('lema_comercial') ?? '';
  }

  Future<String> getLogoUrl() async {
    return await SecureStorageService.read('logo_url') ?? '';
  }

  Future<AuthResult> registrarBodega({
    required String nombreComercial,
    String? ruc,
    String? direccion,
    String? telefono,
    required String adminUsername,
    required String adminPassword,
    String? colorPrimario,
    String? lemaComercial,
    String plan = 'PRO',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/registrar-bodega'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombreComercial': nombreComercial,
          'rucDni': ruc,
          'direccion': direccion,
          'telefono': telefono,
          'username': adminUsername,
          'password': adminPassword,
          'colorPrimario': colorPrimario ?? '#2563EB',
          'lemaComercial': lemaComercial,
        }),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final String token = data['token'];
        final String rol = data['rol'] ?? 'ADMIN';

        await SecureStorageService.write('jwt_token', token);
        await SecureStorageService.write('user_rol', rol);
        await SecureStorageService.write('username', adminUsername);
        if (data['idBodega'] != null) {
          await SecureStorageService.write('id_bodega', data['idBodega'].toString());
        }
        if (data['nombreBodega'] != null) {
          await SecureStorageService.write('nombre_bodega', data['nombreBodega']);
        }
        if (data['plan'] != null) {
          await SecureStorageService.write('plan_bodega', data['plan']);
        }
        if (data['ruc'] != null) {
          await SecureStorageService.write('ruc_bodega', data['ruc']);
        }
        if (data['direccion'] != null) {
          await SecureStorageService.write('direccion_bodega', data['direccion']);
        }
        if (data['telefono'] != null) {
          await SecureStorageService.write('telefono_bodega', data['telefono']);
        }
        if (data['colorPrimario'] != null) {
          await SecureStorageService.write('color_primario', data['colorPrimario']);
        }
        if (data['lemaComercial'] != null) {
          await SecureStorageService.write('lema_comercial', data['lemaComercial']);
        }
        if (data['logoUrl'] != null) {
          await SecureStorageService.write('logo_url', data['logoUrl']);
        }
        return AuthResult(success: true);
      }

      try {
        final errData = jsonDecode(utf8.decode(response.bodyBytes));
        if (errData is Map && errData.containsKey('error')) {
          return AuthResult(success: false, errorMessage: errData['error'].toString());
        }
      } catch (_) {}

      return AuthResult(success: false, errorMessage: 'No se pudo completar el registro de la bodega.');
    } catch (_) {
      return AuthResult(
        success: false,
        errorMessage: 'Error de conexión con el servidor. Verifica tu internet.',
      );
    }
  }
}
