import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';

class UsuarioItem {
  final int idUsuario;
  final String username;
  final String? nombreCompleto;
  final String? email;
  final String rol;
  final bool estado;
  final int? idBodega;
  final String? nombreBodega;
  final String? planBodega;

  UsuarioItem({
    required this.idUsuario,
    required this.username,
    this.nombreCompleto,
    this.email,
    required this.rol,
    required this.estado,
    this.idBodega,
    this.nombreBodega,
    this.planBodega,
  });

  factory UsuarioItem.fromJson(Map<String, dynamic> json) {
    return UsuarioItem(
      idUsuario:
          (json['idUsuario'] as num?)?.toInt() ??
          int.tryParse(json['idUsuario']?.toString() ?? '') ??
          0,
      username: json['username'] ?? '',
      nombreCompleto: json['nombreCompleto'],
      email: json['email'],
      rol: json['rol'] ?? 'CAJERO',
      estado: json['estado'] == true,
      idBodega: json['idBodega'],
      nombreBodega: json['nombreBodega'],
      planBodega: json['planBodega'],
    );
  }
}

class UsuariosService {
  static List<UsuarioItem>? _mockUsuarios;

  @visibleForTesting
  static void setMockUsuarios(List<UsuarioItem>? mockList) {
    _mockUsuarios = mockList != null ? List<UsuarioItem>.from(mockList) : null;
  }

  final ApiClient _client = ApiClient();

  Future<List<UsuarioItem>> listarUsuarios() async {
    if (_mockUsuarios != null) {
      return List<UsuarioItem>.from(_mockUsuarios!);
    }
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
    String? email,
    required String password,
    required String rol,
  }) async {
    if (_mockUsuarios != null) {
      final nextId =
          (_mockUsuarios!.isNotEmpty
              ? _mockUsuarios!
                    .map((u) => u.idUsuario)
                    .reduce((a, b) => a > b ? a : b)
              : 0) +
          1;
      _mockUsuarios!.add(
        UsuarioItem(
          idUsuario: nextId,
          username: username,
          nombreCompleto: nombreCompleto,
          email: email,
          rol: rol,
          estado: true,
        ),
      );
      return;
    }
    final Map<String, dynamic> body = {
      'username': username,
      'password': password,
      'rol': rol,
    };
    if (nombreCompleto != null && nombreCompleto.trim().isNotEmpty) {
      body['nombreCompleto'] = nombreCompleto.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      body['email'] = email.trim();
    }
    final response = await _client.post('/usuarios', body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      final msg = ApiClient.extractErrorMessage(
        response,
        'No se pudo crear el usuario',
      );
      throw Exception(msg);
    }
  }

  Future<void> actualizarEmail(int idUsuario, String email) async {
    final response = await _client.put('/usuarios/$idUsuario/email', {
      'email': email.trim(),
    });
    if (response.statusCode != 200) {
      final msg = ApiClient.extractErrorMessage(
        response,
        'No se pudo actualizar el correo electrónico',
      );
      throw Exception(msg);
    }
  }

  Future<void> actualizarPerfil({
    required int idUsuario,
    String? nombreCompleto,
    String? email,
  }) async {
    final Map<String, dynamic> body = {};
    if (nombreCompleto != null) {
      body['nombreCompleto'] = nombreCompleto.trim();
    }
    if (email != null) {
      body['email'] = email.trim();
    }
    final response = await _client.put('/usuarios/$idUsuario/perfil', body);
    if (response.statusCode != 200) {
      // Fallback a /email si el servidor aún no tiene /perfil disponible
      if (email != null) {
        await actualizarEmail(idUsuario, email);
        return;
      }
      final msg = ApiClient.extractErrorMessage(
        response,
        'No se pudo actualizar los datos del usuario',
      );
      throw Exception(msg);
    }
  }

  Future<void> cambiarEstado(int idUsuario, bool activo) async {
    if (_mockUsuarios != null) {
      final idx = _mockUsuarios!.indexWhere((u) => u.idUsuario == idUsuario);
      if (idx != -1) {
        final curr = _mockUsuarios![idx];
        _mockUsuarios![idx] = UsuarioItem(
          idUsuario: curr.idUsuario,
          username: curr.username,
          nombreCompleto: curr.nombreCompleto,
          email: curr.email,
          rol: curr.rol,
          estado: activo,
          idBodega: curr.idBodega,
          nombreBodega: curr.nombreBodega,
          planBodega: curr.planBodega,
        );
      }
      return;
    }
    final response = await _client.patch(
      '/usuarios/$idUsuario/estado?activo=$activo',
      {},
    );
    if (response.statusCode != 200) {
      final msg = ApiClient.extractErrorMessage(
        response,
        'No se pudo cambiar el estado del usuario',
      );
      throw Exception(msg);
    }
  }

  Future<void> resetPassword(int idUsuario, String nuevaPassword) async {
    if (_mockUsuarios != null) {
      return;
    }
    final response = await _client.put('/usuarios/$idUsuario/reset-password', {
      'nuevaPassword': nuevaPassword,
    });
    if (response.statusCode != 200) {
      final msg = ApiClient.extractErrorMessage(
        response,
        'No se pudo restablecer la contraseña',
      );
      throw Exception(msg);
    }
  }

  Future<void> eliminarUsuario(int idUsuario) async {
    if (_mockUsuarios != null) {
      _mockUsuarios!.removeWhere((u) => u.idUsuario == idUsuario);
      return;
    }
    final response = await _client.delete('/usuarios/$idUsuario');
    if (response.statusCode != 200 && response.statusCode != 204) {
      final msg = ApiClient.extractErrorMessage(
        response,
        'No se pudo eliminar el usuario',
      );
      throw Exception(msg);
    }
  }
}
