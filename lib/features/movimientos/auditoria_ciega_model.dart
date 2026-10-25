/// Modelo de un ítem auditado en la toma de inventario físico
class AuditoriaItem {
  final int idProducto;
  final String nombreProducto;
  final String? codigoBarras;
  final String codigo;
  final String? categoria;
  final double precioVenta;
  final double precioCosto;
  final String? imagenUrl;
  final double stockSistema; // Se mantiene oculto durante el modo ciego
  double conteoFisico; // Unidades contadas en góndola

  AuditoriaItem({
    required this.idProducto,
    required this.nombreProducto,
    this.codigoBarras,
    required this.codigo,
    this.categoria,
    required this.precioVenta,
    required this.precioCosto,
    this.imagenUrl,
    required this.stockSistema,
    this.conteoFisico = 0.0,
  });

  /// Diferencia entre el conteo físico y el stock del sistema
  double get diferencia => conteoFisico - stockSistema;

  bool get esCuadreExacto => diferencia.abs() < 0.001;
  bool get esFaltante => diferencia < -0.001;
  bool get esSobrante => diferencia > 0.001;

  /// Valorización monetaria de la discrepancia (precio de venta o reposición)
  double get valorDiscrepancia => diferencia * precioVenta;

  Map<String, dynamic> toJson() {
    return {
      'idProducto': idProducto,
      'nombreProducto': nombreProducto,
      'codigoBarras': codigoBarras,
      'codigo': codigo,
      'categoria': categoria,
      'precioVenta': precioVenta,
      'precioCosto': precioCosto,
      'imagenUrl': imagenUrl,
      'stockSistema': stockSistema,
      'conteoFisico': conteoFisico,
    };
  }

  factory AuditoriaItem.fromJson(Map<String, dynamic> json) {
    return AuditoriaItem(
      idProducto: (json['idProducto'] as num?)?.toInt() ?? 0,
      nombreProducto: json['nombreProducto'] as String? ?? '',
      codigoBarras: json['codigoBarras'] as String?,
      codigo: json['codigo'] as String? ?? '',
      categoria: json['categoria'] as String?,
      precioVenta: (json['precioVenta'] as num?)?.toDouble() ?? 0.0,
      precioCosto: (json['precioCosto'] as num?)?.toDouble() ?? 0.0,
      imagenUrl: json['imagenUrl'] as String?,
      stockSistema: (json['stockSistema'] as num?)?.toDouble() ?? 0.0,
      conteoFisico: (json['conteoFisico'] as num?)?.toDouble() ?? 0.0,
    );
  }

  AuditoriaItem copyWith({
    int? idProducto,
    String? nombreProducto,
    String? codigoBarras,
    String? codigo,
    String? categoria,
    double? precioVenta,
    double? precioCosto,
    String? imagenUrl,
    double? stockSistema,
    double? conteoFisico,
  }) {
    return AuditoriaItem(
      idProducto: idProducto ?? this.idProducto,
      nombreProducto: nombreProducto ?? this.nombreProducto,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      codigo: codigo ?? this.codigo,
      categoria: categoria ?? this.categoria,
      precioVenta: precioVenta ?? this.precioVenta,
      precioCosto: precioCosto ?? this.precioCosto,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      stockSistema: stockSistema ?? this.stockSistema,
      conteoFisico: conteoFisico ?? this.conteoFisico,
    );
  }
}

/// Sesión de toma de inventario físico ciego
class AuditoriaSesion {
  final String idAuditoria;
  final String titulo;
  final DateTime fechaInicio;
  DateTime? fechaCierre;
  String estado; // 'CONTEO_ACTIVO', 'FINALIZADA', 'REGULARIZADA'
  final String usuarioResponsable;
  final List<AuditoriaItem> items;

  AuditoriaSesion({
    required this.idAuditoria,
    required this.titulo,
    required this.fechaInicio,
    this.fechaCierre,
    this.estado = 'CONTEO_ACTIVO',
    required this.usuarioResponsable,
    required this.items,
  });

  int get totalItemsAuditados => items.where((it) => it.conteoFisico > 0).length;
  int get totalCuadreExacto => items.where((it) => it.esCuadreExacto && it.conteoFisico > 0).length;
  int get totalFaltantes => items.where((it) => it.esFaltante).length;
  int get totalSobrantes => items.where((it) => it.esSobrante).length;

  double get valorPerdidaFaltantes {
    return items.where((it) => it.esFaltante).fold(0.0, (acc, it) => acc + it.valorDiscrepancia.abs());
  }

  double get valorExcedenteSobrantes {
    return items.where((it) => it.esSobrante).fold(0.0, (acc, it) => acc + it.valorDiscrepancia);
  }

  double get discrepanciaNeta => valorExcedenteSobrantes - valorPerdidaFaltantes;

  Map<String, dynamic> toJson() {
    return {
      'idAuditoria': idAuditoria,
      'titulo': titulo,
      'fechaInicio': fechaInicio.toIso8601String(),
      'fechaCierre': fechaCierre?.toIso8601String(),
      'estado': estado,
      'usuarioResponsable': usuarioResponsable,
      'items': items.map((it) => it.toJson()).toList(),
    };
  }

  factory AuditoriaSesion.fromJson(Map<String, dynamic> json) {
    return AuditoriaSesion(
      idAuditoria: json['idAuditoria']?.toString() ?? '',
      titulo: json['titulo'] as String? ?? 'Auditoría Ciega',
      fechaInicio: json['fechaInicio'] != null ? DateTime.tryParse(json['fechaInicio'].toString()) ?? DateTime.now() : DateTime.now(),
      fechaCierre: json['fechaCierre'] != null ? DateTime.tryParse(json['fechaCierre'].toString()) : null,
      estado: json['estado'] as String? ?? 'CONTEO_ACTIVO',
      usuarioResponsable: json['usuarioResponsable'] as String? ?? 'ADMIN',
      items: (json['items'] as List<dynamic>?)
              ?.map((j) => AuditoriaItem.fromJson(j as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
