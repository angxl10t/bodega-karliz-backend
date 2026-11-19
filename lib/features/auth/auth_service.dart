import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/api_client.dart';
import '../../core/api_constants.dart';
import '../../core/offline/offline_catalog_service.dart';
import '../../core/permisos_cajero_service.dart';
import '../../core/secure_storage_service.dart';
import '../catalogo/pedido_web_service.dart';
import '../categorias/categoria_service.dart';
import '../clientes/cliente_service.dart';
import '../clientes/garantia_botella_service.dart';
import '../productos/producto_service.dart';
import '../proveedores/proveedor_service.dart';

class AuthResult {
  final bool success;
  final String? errorMessage;

  AuthResult({required this.success, this.errorMessage});
}

class AuthService {
  AuthService() {
    _ensureCleanupRegistered();
  }

  static bool _cleanupRegistered = false;
  static void _ensureCleanupRegistered() {
    if (_cleanupRegistered) return;
    _cleanupRegistered = true;
    SecureStorageService.registerSessionCleanup(clearAllSessionState);
  }

  static String _cachedRol = 'CAJERO';
  static String get cachedUserRole => _cachedRol;
  static bool get esCajero => _cachedRol == 'CAJERO';
  static bool get esAdmin =>
      _cachedRol == 'ADMIN' ||
      _cachedRol == 'ADMINISTRADOR' ||
      _cachedRol == 'SUPERADMIN';
  static void setCachedRol(String rol) {
    _cachedRol = rol;
  }

  /// Limpia todas las cachés en memoria y sondeos propios de una bodega (ej. al cambiar de tenant).
  static void clearTenantCaches() {
    ProductoService.invalidateCache(notify: false);
    ClienteService.invalidateCache(notify: false);
    CategoriaService.invalidateCache(notify: false);
    ProveedorService.invalidateCache(notify: false);
    GarantiaBotellaService.invalidateCache(notify: false);
    OfflineCatalogService().clearMemoryCache();
    PedidoWebService.resetSession();
  }

  /// Limpia por completo el estado de sesión en memoria (cachés de tenant + rol).
  static void clearAllSessionState() {
    _cachedRol = 'CAJERO';
    clearTenantCaches();
    PermisosCajeroService.resetMemory();
  }

  Future<AuthResult> login(String username, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        clearAllSessionState();
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final String token = data['token'];
        final String rol = data['rol'];
        _cachedRol = rol;

        // Almacenamiento seguro cifrado en hardware (AES-256 / Android Keystore)
        await SecureStorageService.write('jwt_token', token);
        await SecureStorageService.write('user_rol', rol);
        await SecureStorageService.write('username', username);
        if (data['email'] != null) {
          await SecureStorageService.write('user_email', data['email']);
        }
        if (data['idBodega'] != null) {
          final idBod = data['idBodega'].toString();
          await SecureStorageService.write('id_bodega', idBod);
          await SecureStorageService.write('terminal_id_bodega', idBod);
          await PermisosCajeroService.obtenerPermisos(bodegaId: idBod);
        }
        if (data['nombreBodega'] != null) {
          await SecureStorageService.write(
            'nombre_bodega',
            data['nombreBodega'],
          );
          await SecureStorageService.write(
            'terminal_nombre_bodega',
            data['nombreBodega'],
          );
        }
        if (data['giroNegocio'] != null) {
          await SecureStorageService.write('giro_negocio', data['giroNegocio']);
          await SecureStorageService.write(
            'terminal_giro_negocio',
            data['giroNegocio'],
          );
        }
        if (data['plan'] != null) {
          await SecureStorageService.write('plan_bodega', data['plan']);
        }
        if (data['ruc'] != null) {
          await SecureStorageService.write('ruc_bodega', data['ruc']);
        }
        if (data['direccion'] != null) {
          await SecureStorageService.write(
            'direccion_bodega',
            data['direccion'],
          );
        }
        if (data['telefono'] != null) {
          await SecureStorageService.write('telefono_bodega', data['telefono']);
        }
        if (data['colorPrimario'] != null) {
          await SecureStorageService.write(
            'color_primario',
            data['colorPrimario'],
          );
        }
        if (data['lemaComercial'] != null) {
          await SecureStorageService.write(
            'lema_comercial',
            data['lemaComercial'],
          );
        }
        if (data['logoUrl'] != null) {
          await SecureStorageService.write('logo_url', data['logoUrl']);
        }
        if (data['regimenTributario'] != null) {
          await SecureStorageService.write(
            'regimen_tributario',
            data['regimenTributario'],
          );
        }
        if (data['facturacionSunatActiva'] != null) {
          await SecureStorageService.write(
            'facturacion_sunat_activa',
            data['facturacionSunatActiva'].toString(),
          );
        }
        return AuthResult(success: true); // Login exitoso
      }

      if (response.statusCode == 429) {
        final rateMsg = ApiClient.extractErrorMessage(
          response,
          'Demasiados intentos fallidos. Acceso bloqueado temporalmente por seguridad.',
        );
        return AuthResult(success: false, errorMessage: rateMsg);
      }

      final errorMsg = ApiClient.extractErrorMessage(
        response,
        'Usuario o contraseña incorrectos',
      );
      return AuthResult(success: false, errorMessage: errorMsg);
    } on TimeoutException {
      return AuthResult(
        success: false,
        errorMessage: 'El servidor en la nube tardó en responder debido al arranque en frío. Por favor reintenta ingresar ahora que ya ha despertado.',
      );
    } catch (_) {
      return AuthResult(
        success: false,
        errorMessage: 'Error de conexión con el servidor. Verifica tu internet o el estado del servicio.',
      );
    }
  }

  /// Autentica rápidamente a un cajero o mozo en una terminal vinculada con PIN numérico de 4 a 6 dígitos.
  Future<AuthResult> loginCajero({
    required String pin,
    String? idBodega,
    String? codigoTienda,
    int? idUsuario,
  }) async {
    try {
      final Map<String, dynamic> body = {'pin': pin.trim()};
      if (idBodega != null && idBodega.trim().isNotEmpty) {
        body['idBodega'] = int.tryParse(idBodega.trim());
      }
      if (codigoTienda != null && codigoTienda.trim().isNotEmpty) {
        body['codigoTienda'] = codigoTienda.trim();
      }
      if (idUsuario != null) {
        body['idUsuario'] = idUsuario;
      }

      final response = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/auth/login-cajero'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        clearAllSessionState();
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final String token = data['token'];
        final String rol = data['rol'] ?? 'CAJERO';
        _cachedRol = rol;

        await SecureStorageService.write('jwt_token', token);
        await SecureStorageService.write('user_rol', rol);
        if (data['username'] != null) {
          await SecureStorageService.write('username', data['username']);
        }
        if (data['nombreCompleto'] != null) {
          await SecureStorageService.write(
            'nombre_completo',
            data['nombreCompleto'],
          );
        }
        if (data['idBodega'] != null) {
          final idBod = data['idBodega'].toString();
          await SecureStorageService.write('id_bodega', idBod);
          await SecureStorageService.write('terminal_id_bodega', idBod);
          await PermisosCajeroService.obtenerPermisos(bodegaId: idBod);
        }
        if (data['nombreBodega'] != null) {
          await SecureStorageService.write(
            'nombre_bodega',
            data['nombreBodega'],
          );
          await SecureStorageService.write(
            'terminal_nombre_bodega',
            data['nombreBodega'],
          );
        }
        if (data['giroNegocio'] != null) {
          await SecureStorageService.write('giro_negocio', data['giroNegocio']);
          await SecureStorageService.write(
            'terminal_giro_negocio',
            data['giroNegocio'],
          );
        }
        if (data['plan'] != null) {
          await SecureStorageService.write('plan_bodega', data['plan']);
        }
        if (data['ruc'] != null) {
          await SecureStorageService.write('ruc_bodega', data['ruc']);
        }
        if (data['colorPrimario'] != null) {
          await SecureStorageService.write(
            'color_primario',
            data['colorPrimario'],
          );
        }
        return AuthResult(success: true);
      }

      if (response.statusCode == 429) {
        final rateMsg = ApiClient.extractErrorMessage(
          response,
          'Demasiados intentos con PIN. Acceso bloqueado temporalmente por seguridad.',
        );
        return AuthResult(success: false, errorMessage: rateMsg);
      }

      final errorMsg = ApiClient.extractErrorMessage(
        response,
        'PIN incorrecto para esta terminal',
      );
      return AuthResult(success: false, errorMessage: errorMsg);
    } on TimeoutException {
      return AuthResult(
        success: false,
        errorMessage:
            'El servidor tardó en responder. Por favor reintenta ingresar.',
      );
    } catch (_) {
      return AuthResult(
        success: false,
        errorMessage:
            'Error de conexión con el servidor. Verifica tu internet.',
      );
    }
  }

  /// Obtiene los cajeros activos de una tienda para mostrarlos en la pantalla de bloqueo de la terminal.
  Future<List<Map<String, dynamic>>> obtenerCajerosTerminal(
    String idBodega,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${ApiConstants.baseUrl}/auth/terminal/$idBodega/cajeros',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<String?> getTerminalIdBodega() async {
    return await SecureStorageService.read('terminal_id_bodega');
  }

  static Future<String?> getTerminalNombreBodega() async {
    return await SecureStorageService.read('terminal_nombre_bodega');
  }

  static Future<void> vincularTerminal({
    required String idBodega,
    required String nombreBodega,
  }) async {
    await SecureStorageService.write('terminal_id_bodega', idBodega);
    await SecureStorageService.write('terminal_nombre_bodega', nombreBodega);
  }

  static Future<void> desvincularTerminal() async {
    await SecureStorageService.delete('terminal_id_bodega');
    await SecureStorageService.delete('terminal_nombre_bodega');
  }

  /// Realiza un ping ligero en segundo plano para despertar el contenedor de Render
  /// si se encontraba suspendido por inactividad.
  Future<void> precalentarServidor() async {
    try {
      await http
          .get(Uri.parse('${ApiConstants.baseUrl}/health'))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Silencioso: el único propósito es activar el contenedor en Render si estaba en suspensión
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

  Future<String> getUserEmail() async {
    return await SecureStorageService.read('user_email') ?? '';
  }

  Future<void> setUserEmail(String email) async {
    await SecureStorageService.write('user_email', email.trim());
  }

  Future<String> getUserRole() async {
    final r = await SecureStorageService.read('user_rol') ?? 'CAJERO';
    _cachedRol = r;
    return r;
  }

  Future<String> getNombreBodega() async {
    return await SecureStorageService.read('nombre_bodega') ?? 'CajaYa POS';
  }

  Future<String> getPlanBodega() async {
    return await SecureStorageService.read('plan_bodega') ?? 'BASICO';
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

  Future<String> getRegimenTributario() async {
    return await SecureStorageService.read('regimen_tributario') ?? 'NUEVO_RUS';
  }

  Future<String> getGiroNegocio() async {
    return await SecureStorageService.read('giro_negocio') ?? 'BODEGA';
  }

  Future<bool> isFacturacionSunatActiva() async {
    final val = await SecureStorageService.read('facturacion_sunat_activa');
    return val == 'true';
  }

  Future<AuthResult> registrarBodega({
    required String nombreComercial,
    String? ruc,
    String? direccion,
    String? telefono,
    String? email,
    required String adminUsername,
    required String adminPassword,
    String? colorPrimario,
    String? lemaComercial,
    String? regimenTributario,
    String? giroNegocio,
    String plan = 'PRO',
  }) async {
    try {
      final Map<String, dynamic> body = {
        'nombreComercial': nombreComercial,
        'rucDni': ruc,
        'direccion': direccion,
        'telefono': telefono,
        'username': adminUsername,
        'password': adminPassword,
        'colorPrimario': colorPrimario ?? '#2563EB',
        'lemaComercial': lemaComercial,
        'regimenTributario': regimenTributario ?? 'NUEVO_RUS',
        'giroNegocio': giroNegocio ?? 'BODEGA',
        'plan': plan,
      };
      if (email != null && email.trim().isNotEmpty) {
        body['email'] = email.trim();
      }

      final response = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/auth/registrar-bodega'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200 || response.statusCode == 201) {
        clearAllSessionState();
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final String token = data['token'];
        final String rol = data['rol'] ?? 'ADMIN';
        _cachedRol = rol;

        await SecureStorageService.write('jwt_token', token);
        await SecureStorageService.write('user_rol', rol);
        await SecureStorageService.write('username', adminUsername);
        if (data['email'] != null) {
          await SecureStorageService.write('user_email', data['email']);
        }
        if (data['idBodega'] != null) {
          final idBod = data['idBodega'].toString();
          await SecureStorageService.write('id_bodega', idBod);
          await SecureStorageService.write('terminal_id_bodega', idBod);
          await PermisosCajeroService.obtenerPermisos(bodegaId: idBod);
        }
        if (data['nombreBodega'] != null) {
          await SecureStorageService.write(
            'nombre_bodega',
            data['nombreBodega'],
          );
          await SecureStorageService.write(
            'terminal_nombre_bodega',
            data['nombreBodega'],
          );
        }
        if (data['giroNegocio'] != null) {
          await SecureStorageService.write('giro_negocio', data['giroNegocio']);
          await SecureStorageService.write(
            'terminal_giro_negocio',
            data['giroNegocio'],
          );
        }
        if (data['plan'] != null) {
          await SecureStorageService.write('plan_bodega', data['plan']);
        }
        if (data['ruc'] != null) {
          await SecureStorageService.write('ruc_bodega', data['ruc']);
        }
        if (data['direccion'] != null) {
          await SecureStorageService.write(
            'direccion_bodega',
            data['direccion'],
          );
        }
        if (data['telefono'] != null) {
          await SecureStorageService.write('telefono_bodega', data['telefono']);
        }
        if (data['colorPrimario'] != null) {
          await SecureStorageService.write(
            'color_primario',
            data['colorPrimario'],
          );
        }
        if (data['lemaComercial'] != null) {
          await SecureStorageService.write(
            'lema_comercial',
            data['lemaComercial'],
          );
        }
        if (data['logoUrl'] != null) {
          await SecureStorageService.write('logo_url', data['logoUrl']);
        }
        if (data['regimenTributario'] != null) {
          await SecureStorageService.write(
            'regimen_tributario',
            data['regimenTributario'],
          );
        }
        if (data['facturacionSunatActiva'] != null) {
          await SecureStorageService.write(
            'facturacion_sunat_activa',
            data['facturacionSunatActiva'].toString(),
          );
        }
        return AuthResult(success: true);
      }

      final errorMsg = ApiClient.extractErrorMessage(
        response,
        'No se pudo completar el registro de la bodega',
      );
      return AuthResult(success: false, errorMessage: errorMsg);
    } catch (_) {
      return AuthResult(
        success: false,
        errorMessage:
            'Error de conexión con el servidor. Verifica tu internet.',
      );
    }
  }

  // =========================================================================
  // Flujo de Recuperación de Contraseña con Código OTP de 6 Dígitos
  // =========================================================================

  Future<Map<String, dynamic>> solicitarRecuperacionPassword(
    String identificador,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              '${ApiConstants.baseUrl}/auth/recuperar-password/solicitar',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'identificador': identificador.trim()}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'mensaje': data['mensaje'] ?? 'Código enviado con éxito.',
          'emailEnmascarado': data['emailEnmascarado'] ?? '',
          'sinEmail': data['sinEmail'] == 'true',
        };
      }

      final errorMsg = ApiClient.extractErrorMessage(
        response,
        'No se pudo procesar la solicitud de recuperación',
      );
      return {'success': false, 'mensaje': errorMsg};
    } catch (_) {
      return {
        'success': false,
        'mensaje': 'Error de red al solicitar el código. Verifica tu conexión.',
      };
    }
  }

  Future<Map<String, dynamic>> verificarCodigoRecuperacion(
    String identificador,
    String codigo,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              '${ApiConstants.baseUrl}/auth/recuperar-password/verificar',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'identificador': identificador.trim(),
              'codigo': codigo.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'mensaje': data['mensaje'] ?? 'Código verificado correctamente.',
        };
      }

      final errorMsg = ApiClient.extractErrorMessage(
        response,
        'Código de verificación incorrecto o expirado',
      );
      return {'success': false, 'mensaje': errorMsg};
    } catch (_) {
      return {
        'success': false,
        'mensaje': 'Error de conexión al verificar el código.',
      };
    }
  }

  Future<Map<String, dynamic>> restablecerPasswordConCodigo({
    required String identificador,
    required String codigo,
    required String nuevaPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              '${ApiConstants.baseUrl}/auth/recuperar-password/restablecer',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'identificador': identificador.trim(),
              'codigo': codigo.trim(),
              'nuevaPassword': nuevaPassword.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'mensaje': data['mensaje'] ?? 'Contraseña restablecida con éxito.',
          'username': data['username'] ?? identificador,
        };
      }

      final errorMsg = ApiClient.extractErrorMessage(
        response,
        'No se pudo restablecer la contraseña',
      );
      return {'success': false, 'mensaje': errorMsg};
    } catch (_) {
      return {
        'success': false,
        'mensaje': 'Error de conexión al restablecer la contraseña.',
      };
    }
  }
}
