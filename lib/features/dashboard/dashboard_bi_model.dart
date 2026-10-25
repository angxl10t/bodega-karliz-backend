class HorarioPico {
  final int hora;
  final String etiquetaHora;
  final int cantidadTickets;
  final double totalVentas;
  final bool esPico;

  HorarioPico({
    required this.hora,
    required this.etiquetaHora,
    required this.cantidadTickets,
    required this.totalVentas,
    required this.esPico,
  });

  factory HorarioPico.fromJson(Map<String, dynamic> json) {
    return HorarioPico(
      hora: (json['hora'] as num?)?.toInt() ?? 0,
      etiquetaHora: json['etiquetaHora']?.toString() ?? '',
      cantidadTickets: (json['cantidadTickets'] as num?)?.toInt() ?? 0,
      totalVentas: (json['totalVentas'] as num?)?.toDouble() ?? 0.0,
      esPico: json['esPico'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'hora': hora,
    'etiquetaHora': etiquetaHora,
    'cantidadTickets': cantidadTickets,
    'totalVentas': totalVentas,
    'esPico': esPico,
  };
}

class ProductoEstrella {
  final int? idProducto;
  final String nombre;
  final String? codigo;
  final String categoria;
  final String? imagenUrl;
  final double unidadesVendidas;
  final double totalVentas;
  final double costoTotal;
  final double margenBrutoSoles;
  final double porcentajeMargen;

  ProductoEstrella({
    this.idProducto,
    required this.nombre,
    this.codigo,
    required this.categoria,
    this.imagenUrl,
    required this.unidadesVendidas,
    required this.totalVentas,
    required this.costoTotal,
    required this.margenBrutoSoles,
    required this.porcentajeMargen,
  });

  factory ProductoEstrella.fromJson(Map<String, dynamic> json) {
    return ProductoEstrella(
      idProducto: (json['idProducto'] as num?)?.toInt(),
      nombre: json['nombre']?.toString() ?? 'Producto',
      codigo: json['codigo']?.toString(),
      categoria: json['categoria']?.toString() ?? 'General',
      imagenUrl: json['imagenUrl']?.toString(),
      unidadesVendidas: (json['unidadesVendidas'] as num?)?.toDouble() ?? 0.0,
      totalVentas: (json['totalVentas'] as num?)?.toDouble() ?? 0.0,
      costoTotal: (json['costoTotal'] as num?)?.toDouble() ?? 0.0,
      margenBrutoSoles: (json['margenBrutoSoles'] as num?)?.toDouble() ?? 0.0,
      porcentajeMargen: (json['porcentajeMargen'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'idProducto': idProducto,
    'nombre': nombre,
    'codigo': codigo,
    'categoria': categoria,
    'imagenUrl': imagenUrl,
    'unidadesVendidas': unidadesVendidas,
    'totalVentas': totalVentas,
    'costoTotal': costoTotal,
    'margenBrutoSoles': margenBrutoSoles,
    'porcentajeMargen': porcentajeMargen,
  };
}

class ProductoHueso {
  final int? idProducto;
  final String nombre;
  final String? codigo;
  final String categoria;
  final String? imagenUrl;
  final double stockActual;
  final double precioCosto;
  final double capitalInmovilizado;
  final int diasSinVentas;
  final String accionRecomendada;

  ProductoHueso({
    this.idProducto,
    required this.nombre,
    this.codigo,
    required this.categoria,
    this.imagenUrl,
    required this.stockActual,
    required this.precioCosto,
    required this.capitalInmovilizado,
    required this.diasSinVentas,
    required this.accionRecomendada,
  });

  factory ProductoHueso.fromJson(Map<String, dynamic> json) {
    return ProductoHueso(
      idProducto: (json['idProducto'] as num?)?.toInt(),
      nombre: json['nombre']?.toString() ?? 'Producto',
      codigo: json['codigo']?.toString(),
      categoria: json['categoria']?.toString() ?? 'General',
      imagenUrl: json['imagenUrl']?.toString(),
      stockActual: (json['stockActual'] as num?)?.toDouble() ?? 0.0,
      precioCosto: (json['precioCosto'] as num?)?.toDouble() ?? 0.0,
      capitalInmovilizado: (json['capitalInmovilizado'] as num?)?.toDouble() ?? 0.0,
      diasSinVentas: (json['diasSinVentas'] as num?)?.toInt() ?? 30,
      accionRecomendada: json['accionRecomendada']?.toString() ?? 'Promoción o Liquidación',
    );
  }

  Map<String, dynamic> toJson() => {
    'idProducto': idProducto,
    'nombre': nombre,
    'codigo': codigo,
    'categoria': categoria,
    'imagenUrl': imagenUrl,
    'stockActual': stockActual,
    'precioCosto': precioCosto,
    'capitalInmovilizado': capitalInmovilizado,
    'diasSinVentas': diasSinVentas,
    'accionRecomendada': accionRecomendada,
  };
}

class DashboardBiData {
  final int diasAnalizados;
  final double totalVentas;
  final double totalCostos;
  final double margenBrutoSoles;
  final double porcentajeMargenBruto;
  final double ticketPromedioHoy;
  final double ticketPromedioSemanal;
  final double ticketPromedioPeriodo;
  final int cantidadVentasHoy;
  final int cantidadVentasPeriodo;
  final List<ProductoEstrella> productosEstrella;
  final List<ProductoHueso> productosHueso;
  final double totalCapitalInmovilizado;
  final int totalProductosHueso;
  final List<HorarioPico> distribucionHoraria;
  final String horaPicoMaxima;
  final String horaValleMinima;
  final String recomendacionTurnos;

  DashboardBiData({
    required this.diasAnalizados,
    required this.totalVentas,
    required this.totalCostos,
    required this.margenBrutoSoles,
    required this.porcentajeMargenBruto,
    required this.ticketPromedioHoy,
    required this.ticketPromedioSemanal,
    required this.ticketPromedioPeriodo,
    required this.cantidadVentasHoy,
    required this.cantidadVentasPeriodo,
    required this.productosEstrella,
    required this.productosHueso,
    required this.totalCapitalInmovilizado,
    required this.totalProductosHueso,
    required this.distribucionHoraria,
    required this.horaPicoMaxima,
    required this.horaValleMinima,
    required this.recomendacionTurnos,
  });

  factory DashboardBiData.fromJson(Map<String, dynamic> json) {
    return DashboardBiData(
      diasAnalizados: (json['diasAnalizados'] as num?)?.toInt() ?? 30,
      totalVentas: (json['totalVentas'] as num?)?.toDouble() ?? 0.0,
      totalCostos: (json['totalCostos'] as num?)?.toDouble() ?? 0.0,
      margenBrutoSoles: (json['margenBrutoSoles'] as num?)?.toDouble() ?? 0.0,
      porcentajeMargenBruto: (json['porcentajeMargenBruto'] as num?)?.toDouble() ?? 0.0,
      ticketPromedioHoy: (json['ticketPromedioHoy'] as num?)?.toDouble() ?? 0.0,
      ticketPromedioSemanal: (json['ticketPromedioSemanal'] as num?)?.toDouble() ?? 0.0,
      ticketPromedioPeriodo: (json['ticketPromedioPeriodo'] as num?)?.toDouble() ?? 0.0,
      cantidadVentasHoy: (json['cantidadVentasHoy'] as num?)?.toInt() ?? 0,
      cantidadVentasPeriodo: (json['cantidadVentasPeriodo'] as num?)?.toInt() ?? 0,
      productosEstrella: (json['productosEstrella'] as List<dynamic>?)
              ?.map((item) => ProductoEstrella.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      productosHueso: (json['productosHueso'] as List<dynamic>?)
              ?.map((item) => ProductoHueso.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      totalCapitalInmovilizado: (json['totalCapitalInmovilizado'] as num?)?.toDouble() ?? 0.0,
      totalProductosHueso: (json['totalProductosHueso'] as num?)?.toInt() ?? 0,
      distribucionHoraria: (json['distribucionHoraria'] as List<dynamic>?)
              ?.map((item) => HorarioPico.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      horaPicoMaxima: json['horaPicoMaxima']?.toString() ?? '19:00 a 20:00',
      horaValleMinima: json['horaValleMinima']?.toString() ?? '14:00 a 15:00',
      recomendacionTurnos: json['recomendacionTurnos']?.toString() ??
          'Optimiza el personal en horas de mayor afluencia comercial.',
    );
  }

  Map<String, dynamic> toJson() => {
    'diasAnalizados': diasAnalizados,
    'totalVentas': totalVentas,
    'totalCostos': totalCostos,
    'margenBrutoSoles': margenBrutoSoles,
    'porcentajeMargenBruto': porcentajeMargenBruto,
    'ticketPromedioHoy': ticketPromedioHoy,
    'ticketPromedioSemanal': ticketPromedioSemanal,
    'ticketPromedioPeriodo': ticketPromedioPeriodo,
    'cantidadVentasHoy': cantidadVentasHoy,
    'cantidadVentasPeriodo': cantidadVentasPeriodo,
    'productosEstrella': productosEstrella.map((e) => e.toJson()).toList(),
    'productosHueso': productosHueso.map((h) => h.toJson()).toList(),
    'totalCapitalInmovilizado': totalCapitalInmovilizado,
    'totalProductosHueso': totalProductosHueso,
    'distribucionHoraria': distribucionHoraria.map((d) => d.toJson()).toList(),
    'horaPicoMaxima': horaPicoMaxima,
    'horaValleMinima': horaValleMinima,
    'recomendacionTurnos': recomendacionTurnos,
  };
}
