import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_constants.dart';
import 'secure_storage_service.dart';

class ApiClient {
  static void Function()? onSessionExpired;

  /// Extrae el mensaje de error legible desde la respuesta HTTP del servidor
  /// con soporte para campos estándar: 'error', 'message', 'mensaje', 'detail' y texto plano.
  static String extractErrorMessage(http.Response response, [String fallback = 'Error al procesar la solicitud']) {
    try {
      final text = response.body.trim();
      if (text.isNotEmpty) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map) {
            final msg = decoded['error'] ?? decoded['message'] ?? decoded['mensaje'] ?? decoded['detail'];
            if (msg != null && msg.toString().trim().isNotEmpty) {
              return msg.toString().trim();
            }
          } else if (decoded is String && decoded.trim().isNotEmpty) {
            return decoded.trim();
          }
        } catch (_) {
          // Si no es JSON pero es texto plano descriptivo (no HTML ni volcados masivos)
          if (!text.startsWith('<') && text.length < 250) {
            return text;
          }
        }
      }
    } catch (_) {}
    return '$fallback (código ${response.statusCode})';
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await SecureStorageService.read('jwt_token') ?? '';
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }
    return headers;
  }

  void _checkAuthStatus(http.Response response, String endpoint) async {
    // HTTP 401 (No autenticado / Token expirado o revocado)
    final isSessionInvalid = response.statusCode == 401;

    if (isSessionInvalid && !endpoint.contains('/auth/') && !endpoint.contains('/health')) {
      await SecureStorageService.clearAuth();
      onSessionExpired?.call();
    }
  }

  Uri _resolveUri(String endpoint) {
    final clean = endpoint.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return Uri.parse(clean);
    }
    final path = clean.startsWith('/') ? clean : '/$clean';
    return Uri.parse('${ApiConstants.baseUrl}$path');
  }

  @visibleForTesting
  Uri resolveUri(String endpoint) => _resolveUri(endpoint);

  Future<http.Response> get(String endpoint) async {
    final uri = _resolveUri(endpoint);
    final res = await http.get(
      uri,
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 30));
    _checkAuthStatus(res, endpoint);
    return res;
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final uri = _resolveUri(endpoint);
    final res = await http.post(
      uri,
      headers: await _getHeaders(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));
    _checkAuthStatus(res, endpoint);
    return res;
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    final uri = _resolveUri(endpoint);
    final res = await http.put(
      uri,
      headers: await _getHeaders(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));
    _checkAuthStatus(res, endpoint);
    return res;
  }

  Future<http.Response> patch(String endpoint, Map<String, dynamic> body) async {
    final uri = _resolveUri(endpoint);
    final res = await http.patch(
      uri,
      headers: await _getHeaders(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));
    _checkAuthStatus(res, endpoint);
    return res;
  }

  Future<http.Response> delete(String endpoint) async {
    final uri = _resolveUri(endpoint);
    final res = await http.delete(
      uri,
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 30));
    _checkAuthStatus(res, endpoint);
    return res;
  }
}
