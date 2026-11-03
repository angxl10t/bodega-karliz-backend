import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../clientes/cliente_model.dart';
import 'venta_model.dart';

class VentaEnEspera {
  final String id;
  final DateTime fecha;
  final String etiqueta;
  final List<CartItem> items;
  final Cliente? cliente;
  final String metodoPago;
  final String tipoComprobante;
  final double descuentoManualCarrito;
  final String? descuentoManualMotivo;
  final bool aplicarPromocionesWeb;

  VentaEnEspera({
    required this.id,
    required this.fecha,
    required this.etiqueta,
    required this.items,
    this.cliente,
    this.metodoPago = 'Efectivo',
    this.tipoComprobante = 'NOTA_VENTA',
    this.descuentoManualCarrito = 0.0,
    this.descuentoManualMotivo,
    this.aplicarPromocionesWeb = false,
  });

  double get totalBruto => items.fold(0.0, (acc, it) => acc + it.subtotalBruto);

  double get totalNeto {
    final sub = items.fold(0.0, (acc, it) => acc + it.subtotal);
    return (sub - descuentoManualCarrito).clamp(0.0, double.infinity);
  }

  double get totalUnidades => items.fold(0.0, (acc, it) => acc + it.cantidad);

  String get tiempoTranscurrido {
    final diff = DateTime.now().difference(fecha);
    if (diff.inMinutes < 1) return 'Hace instantes';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    return 'Hace ${diff.inHours} h';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fecha': fecha.toIso8601String(),
        'etiqueta': etiqueta,
        'items': items.map((it) => it.toJson()).toList(),
        if (cliente != null) 'cliente': cliente!.toJson(),
        'metodoPago': metodoPago,
        'tipoComprobante': tipoComprobante,
        'descuentoManualCarrito': descuentoManualCarrito,
        if (descuentoManualMotivo != null)
          'descuentoManualMotivo': descuentoManualMotivo,
        'aplicarPromocionesWeb': aplicarPromocionesWeb,
      };

  factory VentaEnEspera.fromJson(Map<String, dynamic> json) => VentaEnEspera(
        id: json['id']?.toString() ?? '',
        fecha: DateTime.tryParse(json['fecha']?.toString() ?? '') ?? DateTime.now(),
        etiqueta: json['etiqueta']?.toString() ?? 'Ticket en Espera',
        items: ((json['items'] as List<dynamic>?) ?? [])
            .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        cliente: json['cliente'] != null
            ? Cliente.fromJson(Map<String, dynamic>.from(json['cliente'] as Map))
            : null,
        metodoPago: json['metodoPago']?.toString() ?? 'Efectivo',
        tipoComprobante: json['tipoComprobante']?.toString() ?? 'NOTA_VENTA',
        descuentoManualCarrito:
            (json['descuentoManualCarrito'] as num?)?.toDouble() ?? 0.0,
        descuentoManualMotivo: json['descuentoManualMotivo']?.toString(),
        aplicarPromocionesWeb: json['aplicarPromocionesWeb'] == true,
      );
}

class VentaEnEsperaService {
  static const String _storageKey = 'cajaya_ventas_en_espera_v1';
  static final List<VentaEnEspera> _ventas = [];
  static final ValueNotifier<int> countNotifier = ValueNotifier<int>(0);

  static List<VentaEnEspera> get ventas => List.unmodifiable(_ventas);

  static Future<void> inicializar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        _ventas.clear();
        for (final item in decoded) {
          _ventas.add(VentaEnEspera.fromJson(Map<String, dynamic>.from(item as Map)));
        }
        countNotifier.value = _ventas.length;
      }
    } catch (_) {}
  }

  static Future<void> ponerEnEspera(VentaEnEspera venta) async {
    _ventas.removeWhere((v) => v.id == venta.id);
    _ventas.insert(0, venta);
    countNotifier.value = _ventas.length;
    await _persistir();
  }

  static Future<VentaEnEspera?> recuperar(String id) async {
    final idx = _ventas.indexWhere((v) => v.id == id);
    if (idx != -1) {
      final venta = _ventas.removeAt(idx);
      countNotifier.value = _ventas.length;
      await _persistir();
      return venta;
    }
    return null;
  }

  static Future<void> eliminar(String id) async {
    _ventas.removeWhere((v) => v.id == id);
    countNotifier.value = _ventas.length;
    await _persistir();
  }

  static Future<void> _persistir() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_ventas.map((v) => v.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (_) {}
  }
}
