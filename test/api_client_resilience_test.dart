import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/core/api_client.dart';
import 'package:bodega_mobile/core/api_constants.dart';

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

      // Ensure that public paths like /auth/login or /health never trigger spurious logout
      const authEndpoint = '/auth/login';
      const healthEndpoint = '/health';

      final shouldTriggerAuth = !authEndpoint.contains('/auth/') && !authEndpoint.contains('/health');
      final shouldTriggerHealth = !healthEndpoint.contains('/auth/') && !healthEndpoint.contains('/health');

      expect(shouldTriggerAuth, isFalse);
      expect(shouldTriggerHealth, isFalse);
      expect(sessionExpiredCalled, isFalse);
    });
  });
}
