import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import 'cliente_model.dart';

class ClienteService {
  final ApiClient _apiClient = ApiClient();

  static List<Cliente>? _cachedClientes;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(seconds: 45);

  static final ValueNotifier<int> clientesRevision = ValueNotifier<int>(0);

  static void invalidateCache() {
    _cachedClientes = null;
    _cacheTimestamp = null;
    clientesRevision.value++;
  }

  Future<List<Cliente>> getClientes({
    String? query,
    bool soloDeudores = false,
    bool forceRefresh = false,
  }) async {
    final hasFilter = (query != null && query.trim().isNotEmpty) || soloDeudores;

    if (!forceRefresh && !hasFilter && _cachedClientes != null && _cacheTimestamp != null) {
      if (DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
        return List<Cliente>.from(_cachedClientes!);
      }
    }

    try {
      final queryParams = <String>[];
      if (query != null && query.trim().isNotEmpty) {
        queryParams.add('query=${Uri.encodeComponent(query.trim())}');
      }
      if (soloDeudores) {
        queryParams.add('soloDeudores=true');
      }

      final endpoint = queryParams.isEmpty ? '/clientes' : '/clientes?${queryParams.join('&')}';
      final response = await _apiClient.get(endpoint);

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        final clientes = list.map((j) => Cliente.fromJson(j as Map<String, dynamic>)).toList();

        if (!hasFilter) {
          _cachedClientes = clientes;
          _cacheTimestamp = DateTime.now();
        }
        return List<Cliente>.from(clientes);
      }
      return _cachedClientes != null ? List<Cliente>.from(_cachedClientes!) : [];
    } catch (e) {
      debugPrint('Error en getClientes: $e');
      return _cachedClientes != null ? List<Cliente>.from(_cachedClientes!) : [];
    }
  }

  Future<Cliente?> getCliente(int id) async {
    try {
      final response = await _apiClient.get('/clientes/$id');
      if (response.statusCode == 200) {
        return Cliente.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      }
      return null;
    } catch (e) {
      debugPrint('Error en getCliente($id): $e');
      return null;
    }
  }

  Future<Cliente> crearCliente(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/clientes', data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      invalidateCache();
      return Cliente.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    }
    final msg = ApiClient.extractErrorMessage(response, 'No se pudo registrar al cliente');
    throw Exception(msg);
  }

  Future<Cliente> actualizarCliente(int id, Map<String, dynamic> data) async {
    final response = await _apiClient.put('/clientes/$id', data);
    if (response.statusCode == 200) {
      invalidateCache();
      return Cliente.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    }
    final msg = ApiClient.extractErrorMessage(response, 'No se pudo actualizar al cliente');
    throw Exception(msg);
  }

  Future<void> eliminarCliente(int id) async {
    final response = await _apiClient.delete('/clientes/$id');
    if (response.statusCode == 200 || response.statusCode == 204) {
      invalidateCache();
      return;
    }
    final msg = ApiClient.extractErrorMessage(response, 'No se pudo dar de baja al cliente');
    throw Exception(msg);
  }

  Future<AbonoCredito> registrarAbono(
    int idCliente, {
    required double monto,
    String metodoPago = 'Efectivo',
    String? notas,
  }) async {
    final body = {
      'monto': monto,
      'metodoPago': metodoPago,
      if (notas != null && notas.trim().isNotEmpty) 'notas': notas.trim(),
    };

    final response = await _apiClient.post('/clientes/$idCliente/abonos', body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      invalidateCache();
      return AbonoCredito.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    }
    final msg = ApiClient.extractErrorMessage(response, 'No se pudo registrar el abono');
    throw Exception(msg);
  }

  Future<List<Cliente>> buscarClientes(String query) => getClientes(query: query);

  Future<ResumenCreditos?> obtenerResumenCreditos() => getResumenCreditos();

  Future<EstadoCuentaCliente?> getEstadoCuenta(int idCliente) async {
    try {
      final response = await _apiClient.get('/clientes/$idCliente/estado-cuenta');
      if (response.statusCode == 200) {
        return EstadoCuentaCliente.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      }
      return null;
    } catch (e) {
      debugPrint('Error en getEstadoCuenta($idCliente): $e');
      return null;
    }
  }

  Future<ResumenCreditos?> getResumenCreditos() async {
    try {
      final response = await _apiClient.get('/clientes/resumen-creditos');
      if (response.statusCode == 200) {
        return ResumenCreditos.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      }
      return null;
    } catch (e) {
      debugPrint('Error en getResumenCreditos: $e');
      return null;
    }
  }

  /// Abre WhatsApp con plantilla comercial amigable pre-cargada
  static Future<bool> abrirWhatsAppRecordatorio({
    required Cliente cliente,
    required String nombreBodega,
    String? numeroYape,
  }) async {
    final telRaw = (cliente.telefono ?? '').replaceAll(RegExp(r'\D'), '');
    if (telRaw.isEmpty) return false;

    // Normalizar a código de país de Perú (51) si tiene 9 dígitos (9XXXXXXXX)
    final tel = telRaw.length == 9 ? '51$telRaw' : telRaw;

    final saludo = 'Hola ${cliente.nombreCompleto}, le saluda *$nombreBodega* 😊.';
    final deudaTexto = 'Le compartimos su estado de cuenta actualizado de fiados: tiene un saldo pendiente de *S/ ${cliente.saldoDeudor.toStringAsFixed(2)}*.';
    final pagoInfo = numeroYape != null && numeroYape.isNotEmpty
        ? '\nPuede cancelar en caja o realizar su pago vía Yape/Plin al número: *$numeroYape*.'
        : '\nPuede cancelar directamente en caja en su próxima visita.';
    final despedida = '\n\n¡Muchas gracias por su preferencia!';

    final mensajeCompleto = '$saludo\n\n$deudaTexto$pagoInfo$despedida';
    final urlString = 'https://wa.me/$tel?text=${Uri.encodeComponent(mensajeCompleto)}';

    final uri = Uri.parse(urlString);
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
