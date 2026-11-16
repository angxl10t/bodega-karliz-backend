class MovimientoInventario {
  final int idMovimiento;
  final int idProducto;
  final String nombreProducto;
  final String tipoMovimiento;
  final double cantidad;
  final String motivo;
  final DateTime? fechaMovimiento;
  final String? usuarioResponsable;

  MovimientoInventario({
    required this.idMovimiento,
    required this.idProducto,
    required this.nombreProducto,
    required this.tipoMovimiento,
    required this.cantidad,
    required this.motivo,
    this.fechaMovimiento,
    this.usuarioResponsable,
  });

  factory MovimientoInventario.fromJson(Map<String, dynamic> json) {
    return MovimientoInventario(
      idMovimiento: (json['idMovimiento'] as num?)?.toInt() ?? 0,
      idProducto: (json['idProducto'] as num?)?.toInt() ?? 0,
      nombreProducto: json['nombreProducto'] as String? ?? 'Producto',
      tipoMovimiento: json['tipoMovimiento'] as String? ?? 'DESCONOCIDO',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0.0,
      motivo: json['motivo'] as String? ?? '',
      fechaMovimiento: parseFechaPeru(json['fechaMovimiento']),
      usuarioResponsable: json['usuarioResponsable'] as String?,
    );
  }

  /// Convierte infaliblemente cualquier fecha/hora a la hora oficial de Perú (UTC-5),
  /// eliminando el desfase de +5 horas provocado por servidores en la nube (Render) o navegadores en UTC.
  static DateTime? parseFechaPeru(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;
    final parsed = DateTime.tryParse(str);
    if (parsed == null) return null;

    if (parsed.isUtc ||
        str.endsWith('Z') ||
        str.contains('+00:00') ||
        str.contains('+0000')) {
      final utc = parsed.toUtc();
      return utc.subtract(const Duration(hours: 5));
    }

    if (str.contains('-05:00') || str.contains('-0500')) {
      return parsed.toLocal();
    }

    // Por defecto, servidores en Render/Docker corren en UTC (naive UTC). Restamos 5 horas a la representación.
    return parsed.subtract(const Duration(hours: 5));
  }
}
