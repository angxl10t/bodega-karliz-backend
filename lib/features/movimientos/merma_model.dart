/// Modelo para el registro detallado de mermas, desmedros y bajas de mercadería
class MermaRegistro {
  final String idMerma;
  final int idProducto;
  final String nombreProducto;
  final double cantidad;
  final String motivo; // 'ROTURA', 'VENCIMIENTO', 'MERMA', 'CONSUMO_INTERNO', 'ROBO_DESMEDRO'
  final double costoUnitario;
  final double costoTotal;
  final String observaciones;
  final String usuarioResponsable;
  final DateTime fecha;

  MermaRegistro({
    required this.idMerma,
    required this.idProducto,
    required this.nombreProducto,
    required this.cantidad,
    required this.motivo,
    required this.costoUnitario,
    required this.costoTotal,
    this.observaciones = '',
    required this.usuarioResponsable,
    required this.fecha,
  });

  Map<String, dynamic> toJson() {
    return {
      'idMerma': idMerma,
      'idProducto': idProducto,
      'nombreProducto': nombreProducto,
      'cantidad': cantidad,
      'motivo': motivo,
      'costoUnitario': costoUnitario,
      'costoTotal': costoTotal,
      'observaciones': observaciones,
      'usuarioResponsable': usuarioResponsable,
      'fecha': fecha.toIso8601String(),
    };
  }

  factory MermaRegistro.fromJson(Map<String, dynamic> json) {
    return MermaRegistro(
      idMerma: json['idMerma']?.toString() ?? '',
      idProducto: (json['idProducto'] as num?)?.toInt() ?? 0,
      nombreProducto: json['nombreProducto'] as String? ?? 'Producto',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0.0,
      motivo: json['motivo'] as String? ?? 'MERMA',
      costoUnitario: (json['costoUnitario'] as num?)?.toDouble() ?? 0.0,
      costoTotal: (json['costoTotal'] as num?)?.toDouble() ?? 0.0,
      observaciones: json['observaciones'] as String? ?? '',
      usuarioResponsable: json['usuarioResponsable'] as String? ?? 'ADMIN',
      fecha: json['fecha'] != null ? DateTime.tryParse(json['fecha'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  String get motivoLegible {
    switch (motivo.toUpperCase()) {
      case 'ROTURA':
        return 'Rotura / Envase Roto';
      case 'VENCIMIENTO':
        return 'Vencimiento / Caducado';
      case 'CONSUMO_INTERNO':
        return 'Consumo Interno';
      case 'ROBO_DESMEDRO':
        return 'Desmedro / Pérdida';
      case 'MERMA':
      default:
        return 'Merma / Deterioro';
    }
  }

  MermaRegistro copyWith({
    String? idMerma,
    int? idProducto,
    String? nombreProducto,
    double? cantidad,
    String? motivo,
    double? costoUnitario,
    double? costoTotal,
    String? observaciones,
    String? usuarioResponsable,
    DateTime? fecha,
  }) {
    return MermaRegistro(
      idMerma: idMerma ?? this.idMerma,
      idProducto: idProducto ?? this.idProducto,
      nombreProducto: nombreProducto ?? this.nombreProducto,
      cantidad: cantidad ?? this.cantidad,
      motivo: motivo ?? this.motivo,
      costoUnitario: costoUnitario ?? this.costoUnitario,
      costoTotal: costoTotal ?? this.costoTotal,
      observaciones: observaciones ?? this.observaciones,
      usuarioResponsable: usuarioResponsable ?? this.usuarioResponsable,
      fecha: fecha ?? this.fecha,
    );
  }
}
