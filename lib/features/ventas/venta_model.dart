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
  final int? idCliente;
  final String? clienteDocumento;
  final String clienteNombre;
  final String metodoPago;
  final List<VentaDetalleEnvio> detalles;
  final String? tipoComprobante;
  final String? idempotencyKey;
  final double? montoRecibido;

  VentaEnvio({
    this.idCliente,
    this.clienteDocumento,
    required this.clienteNombre,
    required this.metodoPago,
    required this.detalles,
    this.tipoComprobante,
    this.idempotencyKey,
    this.montoRecibido,
  });

  Map<String, dynamic> toJson() => {
        if (idCliente != null) 'idCliente': idCliente,
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
  final int? idCliente;
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
    this.idCliente,
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
      idCliente: (json['idCliente'] as num?)?.toInt(),
      clienteDocumento: json['clienteDocumento'] as String?,
      clienteNombre: json['clienteNombre'] as String? ?? 'Público General',
      metodoPago: json['metodoPago'] as String? ?? 'Efectivo',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      montoRecibido: (json['montoRecibido'] as num?)?.toDouble(),
      vuelto: (json['vuelto'] as num?)?.toDouble(),
      fechaVenta: json['fechaVenta'] != null ? DateTime.tryParse(json['fechaVenta'].toString()) : null,
      usuarioRegistro: json['usuarioRegistro'] as String?,
      estado: json['estado'] as String? ?? 'COMPLETADA',
      fechaAnulacion: json['fechaAnulacion'] != null ? DateTime.tryParse(json['fechaAnulacion'].toString()) : null,
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

class EgresoCajaItem {
  final int idEgreso;
  final double monto;
  final String motivo;
  final String categoriaGasto;
  final DateTime? fechaEgreso;
  final String? usuarioRegistro;
  final bool estado;
  final String? usuarioAnulacion;
  final String? motivoAnulacion;

  EgresoCajaItem({
    required this.idEgreso,
    required this.monto,
    required this.motivo,
    this.categoriaGasto = 'VARIOS',
    this.fechaEgreso,
    this.usuarioRegistro,
    this.estado = true,
    this.usuarioAnulacion,
    this.motivoAnulacion,
  });

  factory EgresoCajaItem.fromJson(Map<String, dynamic> json) {
    return EgresoCajaItem(
      idEgreso: (json['idEgreso'] as num?)?.toInt() ?? 0,
      monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
      motivo: json['motivo'] as String? ?? 'Gasto menor',
      categoriaGasto: json['categoriaGasto'] as String? ?? 'VARIOS',
      fechaEgreso: json['fechaEgreso'] != null ? DateTime.tryParse(json['fechaEgreso'].toString()) : null,
      usuarioRegistro: json['usuarioRegistro'] as String?,
      estado: json['estado'] as bool? ?? true,
      usuarioAnulacion: json['usuarioAnulacion'] as String?,
      motivoAnulacion: json['motivoAnulacion'] as String?,
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
  final double totalCredito;
  final int cantidadVentas;
  final DateTime? fecha;

  // Nuevos campos de Arqueo y Control de Turno
  final double fondoInicial;
  final double totalEgresos;
  final double totalEfectivoEsperado;
  final List<EgresoCajaItem> egresos;

  CierreCaja({
    required this.totalVentas,
    required this.totalEfectivo,
    this.totalEfectivoRecibido = 0.0,
    this.totalVueltoEntregado = 0.0,
    required this.totalYape,
    required this.totalPlin,
    required this.totalTarjeta,
    this.totalCredito = 0.0,
    required this.cantidadVentas,
    this.fecha,
    this.fondoInicial = 0.0,
    this.totalEgresos = 0.0,
    double? totalEfectivoEsperado,
    this.egresos = const [],
  }) : totalEfectivoEsperado = totalEfectivoEsperado ?? (fondoInicial + totalEfectivo - totalEgresos);

  factory CierreCaja.fromJson(Map<String, dynamic> json) {
    final double ef = (json['totalEfectivo'] as num?)?.toDouble() ?? 0.0;
    final double fIni = (json['fondoInicial'] as num?)?.toDouble() ?? 0.0;
    final double egr = (json['totalEgresos'] as num?)?.toDouble() ?? 0.0;
    final double? esp = (json['totalEfectivoEsperado'] as num?)?.toDouble();

    final List<EgresoCajaItem> listaEgresos = (json['egresos'] as List<dynamic>?)
            ?.map((e) => EgresoCajaItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return CierreCaja(
      totalVentas: (json['totalVentas'] as num?)?.toDouble() ?? 0.0,
      totalEfectivo: ef,
      totalEfectivoRecibido: (json['totalEfectivoRecibido'] as num?)?.toDouble() ?? ef,
      totalVueltoEntregado: (json['totalVueltoEntregado'] as num?)?.toDouble() ?? 0.0,
      totalYape: (json['totalYape'] as num?)?.toDouble() ?? 0.0,
      totalPlin: (json['totalPlin'] as num?)?.toDouble() ?? 0.0,
      totalTarjeta: (json['totalTarjeta'] as num?)?.toDouble() ?? 0.0,
      totalCredito: (json['totalCredito'] as num?)?.toDouble() ?? 0.0,
      cantidadVentas: (json['cantidadVentas'] as num?)?.toInt() ?? 0,
      fecha: json['fecha'] != null ? DateTime.tryParse(json['fecha'].toString()) : null,
      fondoInicial: fIni,
      totalEgresos: egr,
      totalEfectivoEsperado: esp,
      egresos: listaEgresos,
    );
  }
}
