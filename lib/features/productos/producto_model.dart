enum SemaforoVencimiento {
  sinControl,
  critico, // 🔴 Vencidos o por vencer en menos de 7 días
  atencion, // 🟡 Por vencer en 15 a 30 días (para ponerlos en oferta o remate)
  vigente, // 🟢 Vigentes (> 60 días)
  regular, // 31 a 60 días (rotación regular)
}

class Producto {
  final int? idProducto;
  final int? idCategoria;
  final String? nombreCategoria;
  final String codigo;
  final String? codigoBarras;
  final String nombre;
  final String? marca;
  final double precioVenta;
  final double stockActual;
  final double stockMinimo;
  final bool controlaVencimiento;
  final DateTime? fechaVencimiento;
  final double? precioCosto;
  final String? imagenUrl;

  Producto({
    this.idProducto,
    this.idCategoria,
    this.nombreCategoria,
    required this.codigo,
    this.codigoBarras,
    required this.nombre,
    this.marca,
    required this.precioVenta,
    required this.stockActual,
    this.stockMinimo = 5.0,
    this.controlaVencimiento = false,
    this.fechaVencimiento,
    this.precioCosto,
    this.imagenUrl,
  });

  /// Días restantes para el vencimiento (negativo si ya expiró)
  int? get diasParaVencer {
    if (fechaVencimiento == null) return null;
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final venc = DateTime(fechaVencimiento!.year, fechaVencimiento!.month, fechaVencimiento!.day);
    return venc.difference(hoy).inDays;
  }

  /// Estado semáforo de caducidad según la regla de negocio
  SemaforoVencimiento get semaforoVencimiento {
    final dias = diasParaVencer;
    if (dias == null || !controlaVencimiento) return SemaforoVencimiento.sinControl;
    if (dias <= 7) return SemaforoVencimiento.critico;
    if (dias <= 30) return SemaforoVencimiento.atencion;
    if (dias > 60) return SemaforoVencimiento.vigente;
    return SemaforoVencimiento.regular;
  }

  /// Costo estimado de adquisición para cálculos contables de merma y auditoría
  double get costoUnitarioEstimado => precioCosto ?? (precioVenta * 0.75);

  factory Producto.fromJson(Map<String, dynamic> json) {
    DateTime? parseFecha(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw;
      return DateTime.tryParse(raw.toString());
    }

    return Producto(
      idProducto: (json['idProducto'] as num?)?.toInt(),
      idCategoria: (json['idCategoria'] as num?)?.toInt(),
      nombreCategoria: json['nombreCategoria'] as String?,
      codigo: json['codigo'] as String? ?? '',
      codigoBarras: json['codigoBarras'] as String?,
      nombre: json['nombre'] as String? ?? '',
      marca: json['marca'] as String?,
      precioVenta: (json['precioVenta'] as num?)?.toDouble() ?? 0.0,
      stockActual: (json['stockActual'] as num?)?.toDouble() ?? 0.0,
      stockMinimo: (json['stockMinimo'] as num?)?.toDouble() ?? 5.0,
      controlaVencimiento: json['controlaVencimiento'] as bool? ?? false,
      fechaVencimiento: parseFecha(json['fechaVencimiento'] ?? json['fecha_vencimiento']),
      precioCosto: (json['precioCosto'] as num?)?.toDouble() ?? (json['precio_costo'] as num?)?.toDouble(),
      imagenUrl: json['imagenUrl'] as String? ?? json['imagen_url'] as String?,
    );
  }

  Map<String, dynamic> toJson({bool includeStock = true}) {
    return {
      if (idProducto != null) 'idProducto': idProducto,
      'idCategoria': idCategoria ?? 1,
      'codigo': codigo,
      if (codigoBarras != null) 'codigoBarras': codigoBarras,
      'nombre': nombre,
      if (marca != null) 'marca': marca,
      'precioVenta': precioVenta,
      if (includeStock) 'stockActual': stockActual,
      'stockMinimo': stockMinimo,
      'controlaVencimiento': controlaVencimiento,
      if (fechaVencimiento != null)
        'fechaVencimiento':
            '${fechaVencimiento!.year.toString().padLeft(4, '0')}-${fechaVencimiento!.month.toString().padLeft(2, '0')}-${fechaVencimiento!.day.toString().padLeft(2, '0')}',
      if (precioCosto != null) 'precioCosto': precioCosto,
      'imagenUrl': imagenUrl?.trim() ?? '',
      'estado': true,
    };
  }

  Producto copyWith({
    int? idProducto,
    int? idCategoria,
    String? nombreCategoria,
    String? codigo,
    String? codigoBarras,
    String? nombre,
    String? marca,
    double? precioVenta,
    double? stockActual,
    double? stockMinimo,
    bool? controlaVencimiento,
    DateTime? fechaVencimiento,
    double? precioCosto,
    String? imagenUrl,
  }) {
    return Producto(
      idProducto: idProducto ?? this.idProducto,
      idCategoria: idCategoria ?? this.idCategoria,
      nombreCategoria: nombreCategoria ?? this.nombreCategoria,
      codigo: codigo ?? this.codigo,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      nombre: nombre ?? this.nombre,
      marca: marca ?? this.marca,
      precioVenta: precioVenta ?? this.precioVenta,
      stockActual: stockActual ?? this.stockActual,
      stockMinimo: stockMinimo ?? this.stockMinimo,
      controlaVencimiento: controlaVencimiento ?? this.controlaVencimiento,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      precioCosto: precioCosto ?? this.precioCosto,
      imagenUrl: imagenUrl ?? this.imagenUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Producto &&
          runtimeType == other.runtimeType &&
          idProducto == other.idProducto;

  @override
  int get hashCode => idProducto.hashCode;
}
