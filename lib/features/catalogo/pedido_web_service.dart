import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PedidoWebItem {
  final int idProducto;
  final String nombre;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;
  final String? badge;

  const PedidoWebItem({
    required this.idProducto,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    this.badge,
  });

  Map<String, dynamic> toJson() => {
        'idProducto': idProducto,
        'nombre': nombre,
        'cantidad': cantidad,
        'precioUnitario': precioUnitario,
        'subtotal': subtotal,
        if (badge != null) 'badge': badge,
      };

  factory PedidoWebItem.fromJson(Map<String, dynamic> json) => PedidoWebItem(
        idProducto: (json['idProducto'] as num?)?.toInt() ?? 0,
        nombre: json['nombre']?.toString() ?? 'Producto',
        cantidad: (json['cantidad'] as num?)?.toDouble() ?? 1.0,
        precioUnitario: (json['precioUnitario'] as num?)?.toDouble() ?? 0.0,
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
        badge: json['badge']?.toString(),
      );
}

class PedidoWeb {
  final String idPedido;
  final DateTime fecha;
  final String nombreCliente;
  final String? telefonoCliente;
  final String? notas;
  final List<PedidoWebItem> items;
  final double total;
  final double ahorroPromociones;
  final bool incluyeRetornables;
  String estado; // 'PENDIENTE', 'CARGADO_EN_POS', 'COMPLETADO', 'CANCELADO'

  PedidoWeb({
    required this.idPedido,
    required this.fecha,
    required this.nombreCliente,
    this.telefonoCliente,
    this.notas,
    required this.items,
    required this.total,
    this.ahorroPromociones = 0.0,
    this.incluyeRetornables = false,
    this.estado = 'PENDIENTE',
  });

  Map<String, dynamic> toJson() => {
        'idPedido': idPedido,
        'fecha': fecha.toIso8601String(),
        'nombreCliente': nombreCliente,
        if (telefonoCliente != null) 'telefonoCliente': telefonoCliente,
        if (notas != null) 'notas': notas,
        'items': items.map((i) => i.toJson()).toList(),
        'total': total,
        'ahorroPromociones': ahorroPromociones,
        'incluyeRetornables': incluyeRetornables,
        'estado': estado,
      };

  factory PedidoWeb.fromJson(Map<String, dynamic> json) => PedidoWeb(
        idPedido: json['idPedido']?.toString() ?? '',
        fecha: DateTime.tryParse(json['fecha']?.toString() ?? '') ?? DateTime.now(),
        nombreCliente: json['nombreCliente']?.toString() ?? 'Cliente Web',
        telefonoCliente: json['telefonoCliente']?.toString(),
        notas: json['notas']?.toString(),
        items: ((json['items'] as List<dynamic>?) ?? [])
            .map((e) => PedidoWebItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        total: (json['total'] as num?)?.toDouble() ?? 0.0,
        ahorroPromociones: (json['ahorroPromociones'] as num?)?.toDouble() ?? 0.0,
        incluyeRetornables: json['incluyeRetornables'] == true,
        estado: json['estado']?.toString() ?? 'PENDIENTE',
      );
}

class PedidoWebService {
  static const String _storageKey = 'cajaya_pedidos_web_guardados_v1';
  static final List<PedidoWeb> _pedidos = [];
  static final ValueNotifier<int> pedidosPendientesCountNotifier = ValueNotifier<int>(0);

  static List<PedidoWeb> get pedidos => List.unmodifiable(_pedidos);

  static List<PedidoWeb> get pedidosPendientes =>
      _pedidos.where((p) => p.estado == 'PENDIENTE').toList();

  static Future<void> inicializar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        _pedidos.clear();
        for (final item in decoded) {
          _pedidos.add(PedidoWeb.fromJson(Map<String, dynamic>.from(item as Map)));
        }
        _actualizarConteo();
      }
    } catch (_) {}
  }

  static Future<void> registrarPedido(PedidoWeb pedido) async {
    _pedidos.removeWhere((p) => p.idPedido == pedido.idPedido);
    _pedidos.insert(0, pedido);
    _actualizarConteo();
    await _persistir();
  }

  static Future<void> marcarComoCargadoEnPos(String idPedido) async {
    final idx = _pedidos.indexWhere((p) => p.idPedido == idPedido);
    if (idx != -1) {
      _pedidos[idx].estado = 'CARGADO_EN_POS';
      _actualizarConteo();
      await _persistir();
    }
  }

  static Future<void> eliminarPedido(String idPedido) async {
    _pedidos.removeWhere((p) => p.idPedido == idPedido);
    _actualizarConteo();
    await _persistir();
  }

  static void _actualizarConteo() {
    pedidosPendientesCountNotifier.value =
        _pedidos.where((p) => p.estado == 'PENDIENTE').length;
  }

  static Future<void> _persistir() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_pedidos.map((p) => p.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (_) {}
  }
}
