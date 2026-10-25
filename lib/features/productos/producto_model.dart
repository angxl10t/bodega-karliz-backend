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
    this.imagenUrl,
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
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
