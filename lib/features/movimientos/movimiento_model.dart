class MovimientoInventario {
  final int idMovimiento;
  final int idProducto;
  final String nombreProducto;
  final String tipoMovimiento;
  final double cantidad;
  final String motivo;
  final DateTime? fechaMovimiento;

  MovimientoInventario({
    required this.idMovimiento,
    required this.idProducto,
    required this.nombreProducto,
    required this.tipoMovimiento,
    required this.cantidad,
    required this.motivo,
    this.fechaMovimiento,
  });

  factory MovimientoInventario.fromJson(Map<String, dynamic> json) {
    return MovimientoInventario(
      idMovimiento: (json['idMovimiento'] as num?)?.toInt() ?? 0,
      idProducto: (json['idProducto'] as num?)?.toInt() ?? 0,
      nombreProducto: json['nombreProducto'] as String? ?? 'Producto',
      tipoMovimiento: json['tipoMovimiento'] as String? ?? 'DESCONOCIDO',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0.0,
      motivo: json['motivo'] as String? ?? '',
      fechaMovimiento: json['fechaMovimiento'] != null
          ? DateTime.tryParse(json['fechaMovimiento'])
          : null,
    );
  }
}
