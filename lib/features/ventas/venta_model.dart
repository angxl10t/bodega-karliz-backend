import '../productos/producto_model.dart';

class VentaDetalleEnvio {
  final int idProducto;
  final double cantidad;

  VentaDetalleEnvio({required this.idProducto, required this.cantidad});

  Map<String, dynamic> toJson() => {
        'idProducto': idProducto,
        'cantidad': cantidad,
      };
}

class VentaEnvio {
  final String? clienteDocumento;
  final String clienteNombre;
  final String metodoPago;
  final List<VentaDetalleEnvio> detalles;
  final String? tipoComprobante;
  final String? idempotencyKey;
  final double? montoRecibido;

  VentaEnvio({
    this.clienteDocumento,
    required this.clienteNombre,
    required this.metodoPago,
    required this.detalles,
    this.tipoComprobante,
    this.idempotencyKey,
    this.montoRecibido,
  });

  Map<String, dynamic> toJson() => {
        'clienteDocumento': clienteDocumento,
        'clienteNombre': clienteNombre,
        'metodoPago': metodoPago,
        'detalles': detalles.map((d) => d.toJson()).toList(),
        if (tipoComprobante != null) 'tipoComprobante': tipoComprobante,
        if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
        if (montoRecibido != null) 'montoRecibido': montoRecibido,
      };
}

/// Elemento del Carrito en el Punto de Venta (POS)
class CartItem {
  final Producto producto;
  double cantidad;

  CartItem({required this.producto, this.cantidad = 1.0});

  double get subtotal => producto.precioVenta * cantidad;
}

/// Detalle de venta retornado por la API
class VentaDetalleItem {
  final int? idDetalleVenta;
  final int? idProducto;
  final String nombreProducto;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;

  VentaDetalleItem({
    this.idDetalleVenta,
    this.idProducto,
    required this.nombreProducto,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory VentaDetalleItem.fromJson(Map<String, dynamic> json) {
    return VentaDetalleItem(
      idDetalleVenta: (json['idDetalleVenta'] as num?)?.toInt(),
      idProducto: (json['idProducto'] as num?)?.toInt(),
      nombreProducto: json['nombreProducto'] as String? ?? 'Producto',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0.0,
      precioUnitario: (json['precioUnitario'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Venta histórica retornada por la API
class VentaRegistro {
  final int idVenta;
  final String? clienteDocumento;
  final String? clienteNombre;
  final String metodoPago;
  final double total;
  final DateTime? fechaVenta;
  final String? usuarioRegistro;
  final String estado; // 'COMPLETADA' o 'ANULADA'
  final DateTime? fechaAnulacion;
  final String? usuarioAnulacion;
  final String? motivoAnulacion;
  final String? tipoComprobante;
  final String? serieCorrelativo;
  final String? estadoSunat;
  final String? sunatHash;
  final String? sunatMensaje;
  final String? sunatCdrUrl;
  final String? sunatPdfUrl;
  final String? sunatXmlUrl;
  final double? montoRecibido;
  final double? vuelto;
  final List<VentaDetalleItem> detalles;

  VentaRegistro({
    required this.idVenta,
    this.clienteDocumento,
    this.clienteNombre,
    required this.metodoPago,
    required this.total,
    this.montoRecibido,
    this.vuelto,
    this.fechaVenta,
    this.usuarioRegistro,
    this.estado = 'COMPLETADA',
    this.fechaAnulacion,
    this.usuarioAnulacion,
    this.motivoAnulacion,
    this.tipoComprobante = 'TICKET',
    this.serieCorrelativo,
    this.estadoSunat,
    this.sunatHash,
    this.sunatMensaje,
    this.sunatCdrUrl,
    this.sunatPdfUrl,
    this.sunatXmlUrl,
    required this.detalles,
  });

  bool get isAnulada => estado.toUpperCase() == 'ANULADA';
  bool get esFactura => tipoComprobante == 'FACTURA_ELECTRONICA';
  bool get esBoleta => tipoComprobante == 'BOLETA_ELECTRONICA';
  bool get esSunat => esFactura || esBoleta;
  String get etiquetaComprobante {
    if (esFactura) return 'Factura ${serieCorrelativo ?? "#$idVenta"}';
    if (esBoleta) return 'Boleta ${serieCorrelativo ?? "#$idVenta"}';
    return 'Ticket #$idVenta';
  }

  factory VentaRegistro.fromJson(Map<String, dynamic> json) {
    return VentaRegistro(
      idVenta: (json['idVenta'] as num?)?.toInt() ?? 0,
      clienteDocumento: json['clienteDocumento'] as String?,
      clienteNombre: json['clienteNombre'] as String? ?? 'Público General',
      metodoPago: json['metodoPago'] as String? ?? 'Efectivo',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      montoRecibido: (json['montoRecibido'] as num?)?.toDouble(),
      vuelto: (json['vuelto'] as num?)?.toDouble(),
      fechaVenta: json['fechaVenta'] != null ? DateTime.tryParse(json['fechaVenta']) : null,
      usuarioRegistro: json['usuarioRegistro'] as String?,
      estado: json['estado'] as String? ?? 'COMPLETADA',
      fechaAnulacion: json['fechaAnulacion'] != null ? DateTime.tryParse(json['fechaAnulacion']) : null,
      usuarioAnulacion: json['usuarioAnulacion'] as String?,
      motivoAnulacion: json['motivoAnulacion'] as String?,
      tipoComprobante: json['tipoComprobante'] as String? ?? 'TICKET',
      serieCorrelativo: json['serieCorrelativo'] as String?,
      estadoSunat: json['estadoSunat'] as String?,
      sunatHash: json['sunatHash'] as String?,
      sunatMensaje: json['sunatMensaje'] as String?,
      sunatCdrUrl: json['sunatCdrUrl'] as String?,
      sunatPdfUrl: json['sunatPdfUrl'] as String?,
      sunatXmlUrl: json['sunatXmlUrl'] as String?,
      detalles: (json['detalles'] as List<dynamic>?)
              ?.map((d) => VentaDetalleItem.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Resumen financiero para Arqueo / Cierre de Caja
class CierreCaja {
  final double totalVentas;
  final double totalEfectivo;
  final double totalEfectivoRecibido;
  final double totalVueltoEntregado;
  final double totalYape;
  final double totalPlin;
  final double totalTarjeta;
  final int cantidadVentas;
  final DateTime? fecha;

  CierreCaja({
    required this.totalVentas,
    required this.totalEfectivo,
    this.totalEfectivoRecibido = 0.0,
    this.totalVueltoEntregado = 0.0,
    required this.totalYape,
    required this.totalPlin,
    required this.totalTarjeta,
    required this.cantidadVentas,
    this.fecha,
  });

  factory CierreCaja.fromJson(Map<String, dynamic> json) {
    final double ef = (json['totalEfectivo'] as num?)?.toDouble() ?? 0.0;
    return CierreCaja(
      totalVentas: (json['totalVentas'] as num?)?.toDouble() ?? 0.0,
      totalEfectivo: ef,
      totalEfectivoRecibido: (json['totalEfectivoRecibido'] as num?)?.toDouble() ?? ef,
      totalVueltoEntregado: (json['totalVueltoEntregado'] as num?)?.toDouble() ?? 0.0,
      totalYape: (json['totalYape'] as num?)?.toDouble() ?? 0.0,
      totalPlin: (json['totalPlin'] as num?)?.toDouble() ?? 0.0,
      totalTarjeta: (json['totalTarjeta'] as num?)?.toDouble() ?? 0.0,
      cantidadVentas: (json['cantidadVentas'] as num?)?.toInt() ?? 0,
      fecha: json['fecha'] != null ? DateTime.tryParse(json['fecha']) : null,
    );
  }
}
