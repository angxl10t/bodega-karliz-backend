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
}
