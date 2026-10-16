class CompraDetalleEnvio {
  final int idProducto;
  final double cantidad;
  final double precioUnitario;

  CompraDetalleEnvio({
    required this.idProducto,
    required this.cantidad,
    required this.precioUnitario,
  });

  Map<String, dynamic> toJson() => {
        'idProducto': idProducto,
        'cantidad': cantidad,
        'precioUnitario': precioUnitario,
      };
}

class CompraEnvio {
  final int idProveedor;
  final String comprobante;
  final List<CompraDetalleEnvio> detalles;

  CompraEnvio({
    required this.idProveedor,
    required this.comprobante,
    required this.detalles,
  });

  Map<String, dynamic> toJson() => {
        'idProveedor': idProveedor,
        'comprobante': comprobante,
        'detalles': detalles.map((d) => d.toJson()).toList(),
      };
}

/// Item en canasta de compra multilínea
class CompraCartItem {
  final int idProducto;
  final String nombreProducto;
  final String codigo;
  double cantidad;
  double precioUnitario;

  CompraCartItem({
    required this.idProducto,
    required this.nombreProducto,
    required this.codigo,
    required this.cantidad,
    required this.precioUnitario,
  });

  double get subtotal => cantidad * precioUnitario;
}

/// Detalle de compra retornado por la API
class CompraDetalleItem {
  final int? idDetalleCompra;
  final int? idProducto;
  final String nombreProducto;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;

  CompraDetalleItem({
    this.idDetalleCompra,
    this.idProducto,
    required this.nombreProducto,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory CompraDetalleItem.fromJson(Map<String, dynamic> json) {
    return CompraDetalleItem(
      idDetalleCompra: (json['idDetalleCompra'] as num?)?.toInt(),
      idProducto: (json['idProducto'] as num?)?.toInt(),
      nombreProducto: json['nombreProducto'] as String? ?? 'Producto',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0.0,
      precioUnitario: (json['precioUnitario'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Compra histórica registrada
class CompraRegistro {
  final int idCompra;
  final int idProveedor;
  final String razonSocialProveedor;
  final String comprobante;
  final double total;
  final DateTime? fechaCompra;
  final List<CompraDetalleItem> detalles;

  CompraRegistro({
    required this.idCompra,
    required this.idProveedor,
    required this.razonSocialProveedor,
    required this.comprobante,
    required this.total,
    this.fechaCompra,
    required this.detalles,
  });

  factory CompraRegistro.fromJson(Map<String, dynamic> json) {
    return CompraRegistro(
      idCompra: (json['idCompra'] as num?)?.toInt() ?? 0,
      idProveedor: (json['idProveedor'] as num?)?.toInt() ?? 0,
      razonSocialProveedor: json['razonSocialProveedor'] as String? ?? 'Proveedor',
      comprobante: json['comprobante'] as String? ?? 'S/C',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      fechaCompra: json['fechaCompra'] != null ? DateTime.tryParse(json['fechaCompra']) : null,
      detalles: (json['detalles'] as List<dynamic>?)
              ?.map((d) => CompraDetalleItem.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
