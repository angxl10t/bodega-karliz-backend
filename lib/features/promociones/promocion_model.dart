class Promocion {
  final int idPromocion;
  final int? idBodega;
  final String titulo;
  final String descripcion;
  final String tipoPromocion; // PORCENTAJE, MONTO_FIJO, DOS_POR_UNO, TRES_POR_DOS, COMBO_HUESO
  final String alcance;       // CATEGORIA, MARCA, PRODUCTO, COMBO
  final double valorDescuento;
  final String? categoriaObjetivo;
  final String? marcaObjetivo;
  final int? idProductoPrincipal;
  final String? nombreProductoPrincipal;
  final int? idProductoSecundario;
  final String? nombreProductoSecundario;
  final double? precioCombo;
  final String badgeTexto;
  final String colorBadge;
  final String? fechaInicio;
  final String? fechaFin;
  final bool activo;
  final bool esSugerenciaHueso;

  const Promocion({
    required this.idPromocion,
    this.idBodega,
    required this.titulo,
    this.descripcion = '',
    required this.tipoPromocion,
    required this.alcance,
    this.valorDescuento = 0.0,
    this.categoriaObjetivo,
    this.marcaObjetivo,
    this.idProductoPrincipal,
    this.nombreProductoPrincipal,
    this.idProductoSecundario,
    this.nombreProductoSecundario,
    this.precioCombo,
    this.badgeTexto = '🔥 OFERTA',
    this.colorBadge = '#EF4444',
    this.fechaInicio,
    this.fechaFin,
    this.activo = true,
    this.esSugerenciaHueso = false,
  });

  factory Promocion.fromJson(Map<String, dynamic> json) {
    return Promocion(
      idPromocion: (json['idPromocion'] as num?)?.toInt() ?? 0,
      idBodega: (json['idBodega'] as num?)?.toInt(),
      titulo: json['titulo']?.toString() ?? 'Promoción',
      descripcion: json['descripcion']?.toString() ?? '',
      tipoPromocion: json['tipoPromocion']?.toString() ?? 'PORCENTAJE',
      alcance: json['alcance']?.toString() ?? 'CATEGORIA',
      valorDescuento: (json['valorDescuento'] as num?)?.toDouble() ?? 0.0,
      categoriaObjetivo: json['categoriaObjetivo']?.toString(),
      marcaObjetivo: json['marcaObjetivo']?.toString(),
      idProductoPrincipal: (json['idProductoPrincipal'] as num?)?.toInt(),
      nombreProductoPrincipal: json['nombreProductoPrincipal']?.toString(),
      idProductoSecundario: (json['idProductoSecundario'] as num?)?.toInt(),
      nombreProductoSecundario: json['nombreProductoSecundario']?.toString(),
      precioCombo: (json['precioCombo'] as num?)?.toDouble(),
      badgeTexto: json['badgeTexto']?.toString() ?? '🔥 OFERTA',
      colorBadge: json['colorBadge']?.toString() ?? '#EF4444',
      fechaInicio: json['fechaInicio']?.toString(),
      fechaFin: json['fechaFin']?.toString(),
      activo: json['activo'] == true,
      esSugerenciaHueso: json['esSugerenciaHueso'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idPromocion': idPromocion,
      'idBodega': idBodega,
      'titulo': titulo,
      'descripcion': descripcion,
      'tipoPromocion': tipoPromocion,
      'alcance': alcance,
      'valorDescuento': valorDescuento,
      'categoriaObjetivo': categoriaObjetivo,
      'marcaObjetivo': marcaObjetivo,
      'idProductoPrincipal': idProductoPrincipal,
      'nombreProductoPrincipal': nombreProductoPrincipal,
      'idProductoSecundario': idProductoSecundario,
      'nombreProductoSecundario': nombreProductoSecundario,
      'precioCombo': precioCombo,
      'badgeTexto': badgeTexto,
      'colorBadge': colorBadge,
      'fechaInicio': fechaInicio,
      'fechaFin': fechaFin,
      'activo': activo,
      'esSugerenciaHueso': esSugerenciaHueso,
    };
  }
}

class SugerenciaComboHueso {
  final int idProductoHueso;
  final String nombreHueso;
  final String categoriaHueso;
  final String? imagenUrlHueso;
  final double stockHueso;
  final double costoHueso;
  final double precioRegularHueso;
  final double capitalInmovilizado;

  final int idProductoEstrella;
  final String nombreEstrella;
  final String categoriaEstrella;
  final String? imagenUrlEstrella;
  final double precioRegularEstrella;

  final String tituloSugerido;
  final String descripcionSugerida;
  final double precioRegularTotal;
  final double precioComboSugerido;
  final double ahorroCliente;
  final double porcentajeDescuentoSugerido;
  final String razonEstrategica;
  final String badgeSugerido;

  const SugerenciaComboHueso({
    required this.idProductoHueso,
    required this.nombreHueso,
    required this.categoriaHueso,
    this.imagenUrlHueso,
    required this.stockHueso,
    required this.costoHueso,
    required this.precioRegularHueso,
    required this.capitalInmovilizado,
    required this.idProductoEstrella,
    required this.nombreEstrella,
    required this.categoriaEstrella,
    this.imagenUrlEstrella,
    required this.precioRegularEstrella,
    required this.tituloSugerido,
    required this.descripcionSugerida,
    required this.precioRegularTotal,
    required this.precioComboSugerido,
    required this.ahorroCliente,
    required this.porcentajeDescuentoSugerido,
    required this.razonEstrategica,
    required this.badgeSugerido,
  });

  factory SugerenciaComboHueso.fromJson(Map<String, dynamic> json) {
    return SugerenciaComboHueso(
      idProductoHueso: (json['idProductoHueso'] as num?)?.toInt() ?? 0,
      nombreHueso: json['nombreHueso']?.toString() ?? '',
      categoriaHueso: json['categoriaHueso']?.toString() ?? 'General',
      imagenUrlHueso: json['imagenUrlHueso']?.toString(),
      stockHueso: (json['stockHueso'] as num?)?.toDouble() ?? 0.0,
      costoHueso: (json['costoHueso'] as num?)?.toDouble() ?? 0.0,
      precioRegularHueso: (json['precioRegularHueso'] as num?)?.toDouble() ?? 0.0,
      capitalInmovilizado: (json['capitalInmovilizado'] as num?)?.toDouble() ?? 0.0,
      idProductoEstrella: (json['idProductoEstrella'] as num?)?.toInt() ?? 0,
      nombreEstrella: json['nombreEstrella']?.toString() ?? '',
      categoriaEstrella: json['categoriaEstrella']?.toString() ?? 'General',
      imagenUrlEstrella: json['imagenUrlEstrella']?.toString(),
      precioRegularEstrella: (json['precioRegularEstrella'] as num?)?.toDouble() ?? 0.0,
      tituloSugerido: json['tituloSugerido']?.toString() ?? 'Combo Dúo',
      descripcionSugerida: json['descripcionSugerida']?.toString() ?? '',
      precioRegularTotal: (json['precioRegularTotal'] as num?)?.toDouble() ?? 0.0,
      precioComboSugerido: (json['precioComboSugerido'] as num?)?.toDouble() ?? 0.0,
      ahorroCliente: (json['ahorroCliente'] as num?)?.toDouble() ?? 0.0,
      porcentajeDescuentoSugerido: (json['porcentajeDescuentoSugerido'] as num?)?.toDouble() ?? 15.0,
      razonEstrategica: json['razonEstrategica']?.toString() ?? '',
      badgeSugerido: json['badgeSugerido']?.toString() ?? '⭐ COMBO -15%',
    );
  }
}
