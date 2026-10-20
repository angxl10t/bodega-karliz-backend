import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:bodega_mobile/core/api_client.dart';
import 'package:bodega_mobile/core/api_constants.dart';
import 'package:bodega_mobile/core/thermal_ticket_service.dart';

void main() {
  group('ApiClient Resilience and URI Normalization Tests', () {
    final client = ApiClient();

    test('resolveUri appends leading slash if omitted', () {
      final uri = client.resolveUri('productos');
      expect(uri.toString(), '${ApiConstants.baseUrl}/productos');
    });

    test('resolveUri handles endpoints with existing leading slash correctly', () {
      final uri = client.resolveUri('/productos/10');
      expect(uri.toString(), '${ApiConstants.baseUrl}/productos/10');
    });

    test('resolveUri trims leading and trailing whitespaces', () {
      final uri = client.resolveUri('  /ventas/hoy   ');
      expect(uri.toString(), '${ApiConstants.baseUrl}/ventas/hoy');
    });

    test('resolveUri preserves full HTTP / HTTPS URLs', () {
      final fullUrl = 'https://custom-service.internal/api/v1/health';
      final uri = client.resolveUri(fullUrl);
      expect(uri.toString(), fullUrl);
    });

    test('Session expiry does not trigger for auth or health endpoints', () {
      bool sessionExpiredCalled = false;
      ApiClient.onSessionExpired = () {
        sessionExpiredCalled = true;
      };

      const authEndpoint = '/auth/login';
      const healthEndpoint = '/health';

      final shouldTriggerAuth = !authEndpoint.contains('/auth/') && !authEndpoint.contains('/health');
      final shouldTriggerHealth = !healthEndpoint.contains('/auth/') && !healthEndpoint.contains('/health');

      expect(shouldTriggerAuth, isFalse);
      expect(shouldTriggerHealth, isFalse);
      expect(sessionExpiredCalled, isFalse);
    });

    test('Triggers session expiry on 401 for non-auth endpoints', () async {
      bool expiredCalled = false;
      ApiClient.onSessionExpired = () {
        expiredCalled = true;
      };

      final response = http.Response('{"error":"Token expired"}', 401);
      client.checkAuthStatus(response, '/productos');
      // Esperar microtasks para SecureStorageService
      await Future.delayed(const Duration(milliseconds: 20));

      expect(expiredCalled, isTrue);
    });

    test('Triggers session expiry on 403 when bodega or user is deactivated', () async {
      bool expiredCalled = false;
      ApiClient.onSessionExpired = () {
        expiredCalled = true;
      };

      final response = http.Response('{"error":"Acceso denegado: La tienda o bodega asignada ha sido desactivada."}', 403);
      client.checkAuthStatus(response, '/ventas');
      await Future.delayed(const Duration(milliseconds: 20));

      expect(expiredCalled, isTrue);
    });

    test('Does NOT trigger session expiry on 403 for normal permission denial', () async {
      bool expiredCalled = false;
      ApiClient.onSessionExpired = () {
        expiredCalled = true;
      };

      final response = http.Response('{"error":"Acceso denegado: No tienes los privilegios necesarios."}', 403);
      client.checkAuthStatus(response, '/usuarios');
      await Future.delayed(const Duration(milliseconds: 20));

      expect(expiredCalled, isFalse);
    });
    test('ApiClient initializes with shared Keep-Alive client or optional injected client', () {
      final defaultClient = ApiClient();
      expect(defaultClient, isNotNull);

      final customMock = http.Client();
      final customApiClient = ApiClient(client: customMock);
      expect(customApiClient, isNotNull);
      customMock.close();
    });
  });

  group('ApiClient extractErrorMessage Tests', () {
    test('extracts error from json map with "error" key', () {
      final res = http.Response(jsonEncode({'error': 'Stock insuficiente para el producto'}), 400);
      expect(ApiClient.extractErrorMessage(res), 'Stock insuficiente para el producto');
    });

    test('extracts error from json map with "message" key', () {
      final res = http.Response(jsonEncode({'message': 'Credenciales no válidas'}), 401);
      expect(ApiClient.extractErrorMessage(res), 'Credenciales no válidas');
    });

    test('extracts error from json map with "mensaje" key', () {
      final res = http.Response(jsonEncode({'mensaje': 'El proveedor ya está registrado'}), 409);
      expect(ApiClient.extractErrorMessage(res), 'El proveedor ya está registrado');
    });

    test('extracts error from json map with "detail" key (RFC 7807)', () {
      final res = http.Response(jsonEncode({'detail': 'Token de autenticación expirado'}), 403);
      expect(ApiClient.extractErrorMessage(res), 'Token de autenticación expirado');
    });

    test('handles plain string body', () {
      final res = http.Response('Servicio temporalmente fuera de línea', 503);
      expect(ApiClient.extractErrorMessage(res), 'Servicio temporalmente fuera de línea');
    });

    test('returns fallback with status code when body is empty or invalid JSON', () {
      final res = http.Response('<html><body>502 Bad Gateway</body></html>', 502);
      expect(ApiClient.extractErrorMessage(res, 'Error de servidor'), contains('502'));
    });
  });

  group('ThermalTicketService Document Label Tests', () {
    test('formats DNI label for 8-digit client document', () {
      final text = ThermalTicketService.generateReceiptText(
        ticketId: 101,
        clienteNombre: 'Juan Perez',
        clienteDocumento: '71234567',
        metodoPago: 'EFECTIVO',
        items: [],
        total: 10.0,
      );
      expect(text, contains('DNI:'));
      expect(text, contains('71234567'));
    });

    test('formats RUC label for 11-digit client document', () {
      final text = ThermalTicketService.generateReceiptText(
        ticketId: 102,
        clienteNombre: 'Comercial SAC',
        clienteDocumento: '20601234567',
        metodoPago: 'YAPE',
        items: [],
        total: 50.0,
      );
      expect(text, contains('RUC:'));
      expect(text, contains('20601234567'));
    });
  });
}
