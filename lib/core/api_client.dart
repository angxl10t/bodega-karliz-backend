import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';
import 'secure_storage_service.dart';

class ApiClient {
  static void Function()? onSessionExpired;

  Future<Map<String, String>> _getHeaders() async {
    final token = await SecureStorageService.read('jwt_token') ?? '';
    return {
      'Content-Type': 'application/json',
      // Inyectamos el JWT cifrado en hardware en cada petición
      'Authorization': 'Bearer $token',
    };
  }

  void _checkAuthStatus(http.Response response, String endpoint) async {
    // HTTP 401 (No autenticado / Token expirado o revocado)
    final isSessionInvalid = response.statusCode == 401;

    if (isSessionInvalid && !endpoint.contains('/auth/login')) {
      await SecureStorageService.clearAuth();
      onSessionExpired?.call();
    }
  }

  Future<http.Response> get(String endpoint) async {
    final res = await http.get(
      Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 30));
    _checkAuthStatus(res, endpoint);
    return res;
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));
    _checkAuthStatus(res, endpoint);
    return res;
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));
    _checkAuthStatus(res, endpoint);
    return res;
  }

  Future<http.Response> patch(String endpoint, Map<String, dynamic> body) async {
    final res = await http.patch(
      Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));
    _checkAuthStatus(res, endpoint);
    return res;
  }

  Future<http.Response> delete(String endpoint) async {
    final res = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 30));
    _checkAuthStatus(res, endpoint);
    return res;
  }
}
