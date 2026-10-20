import 'dart:convert';
import '../../core/api_client.dart';

class UsuarioItem {
  final int idUsuario;
  final String username;
  final String? nombreCompleto;
  final String rol;
  final bool estado;
  final int? idBodega;
  final String? nombreBodega;
  final String? planBodega;

  UsuarioItem({
    required this.idUsuario,
    required this.username,
    this.nombreCompleto,
    required this.rol,
    required this.estado,
    this.idBodega,
    this.nombreBodega,
    this.planBodega,
  });

  factory UsuarioItem.fromJson(Map<String, dynamic> json) {
    return UsuarioItem(
      idUsuario: json['idUsuario'] is int ? json['idUsuario'] : int.parse(json['idUsuario'].toString()),
      username: json['username'] ?? '',
      nombreCompleto: json['nombreCompleto'],
      rol: json['rol'] ?? 'CAJERO',
      estado: json['estado'] == true,
      idBodega: json['idBodega'],
      nombreBodega: json['nombreBodega'],
      planBodega: json['planBodega'],
    );
  }
}

class UsuariosService {
  final ApiClient _client = ApiClient();

  Future<List<UsuarioItem>> listarUsuarios() async {
    final response = await _client.get('/usuarios');
    if (response.statusCode == 200) {
      final List data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((e) => UsuarioItem.fromJson(e)).toList();
    }
    return [];
  }

  Future<void> crearUsuario({
    required String username,
    String? nombreCompleto,
    required String password,
    required String rol,
  }) async {
    final Map<String, dynamic> body = {
      'username': username,
      'password': password,
      'rol': rol,
    };
    if (nombreCompleto != null && nombreCompleto.trim().isNotEmpty) {
      body['nombreCompleto'] = nombreCompleto.trim();
    }
    final response = await _client.post('/usuarios', body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      final msg = ApiClient.extractErrorMessage(response, 'No se pudo crear el usuario');
      throw Exception(msg);
    }
  }

  Future<void> cambiarEstado(int idUsuario, bool activo) async {
    final response = await _client.patch('/usuarios/$idUsuario/estado?activo=$activo', {});
    if (response.statusCode != 200) {
      final msg = ApiClient.extractErrorMessage(response, 'No se pudo cambiar el estado del usuario');
      throw Exception(msg);
    }
  }

  Future<void> resetPassword(int idUsuario, String nuevaPassword) async {
    final response = await _client.put('/usuarios/$idUsuario/reset-password', {
      'nuevaPassword': nuevaPassword,
    });
    if (response.statusCode != 200) {
      final msg = ApiClient.extractErrorMessage(response, 'No se pudo restablecer la contraseña');
      throw Exception(msg);
    }
  }
}
