class Cliente {
  final int? idCliente;
  final int? idBodega;
  final String? documento;
  final String nombreCompleto;
  final String? telefono;
  final String? direccion;
  final double limiteCredito;
  final double saldoDeudor;
  final double creditoDisponible;
  final String? notas;
  final bool estado;
  final DateTime? fechaRegistro;
  final DateTime? fechaUltimoPago;

  Cliente({
    this.idCliente,
    this.idBodega,
    this.documento,
    required this.nombreCompleto,
    this.telefono,
    this.direccion,
    this.limiteCredito = 200.0,
    this.saldoDeudor = 0.0,
    this.creditoDisponible = 200.0,
    this.notas,
    this.estado = true,
    this.fechaRegistro,
    this.fechaUltimoPago,
  });

  bool get tieneDeuda => saldoDeudor > 0.009;
  double get porcentajeCreditoUsado => limiteCredito > 0 ? (saldoDeudor / limiteCredito).clamp(0.0, 1.0) : 0.0;

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      idCliente: (json['idCliente'] as num?)?.toInt(),
      idBodega: (json['idBodega'] as num?)?.toInt(),
      documento: json['documento'] as String?,
      nombreCompleto: json['nombreCompleto'] as String? ?? 'Sin Nombre',
      telefono: json['telefono'] as String?,
      direccion: json['direccion'] as String?,
      limiteCredito: (json['limiteCredito'] as num?)?.toDouble() ?? 200.0,
      saldoDeudor: (json['saldoDeudor'] as num?)?.toDouble() ?? 0.0,
      creditoDisponible: (json['creditoDisponible'] as num?)?.toDouble() ?? 200.0,
      notas: json['notas'] as String?,
      estado: json['estado'] as bool? ?? true,
      fechaRegistro: json['fechaRegistro'] != null ? DateTime.tryParse(json['fechaRegistro']) : null,
      fechaUltimoPago: json['fechaUltimoPago'] != null ? DateTime.tryParse(json['fechaUltimoPago']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (idCliente != null) 'idCliente': idCliente,
      'documento': documento?.trim(),
      'nombreCompleto': nombreCompleto.trim(),
      'telefono': telefono?.trim(),
      'direccion': direccion?.trim(),
      'limiteCredito': limiteCredito,
      'notas': notas?.trim(),
      'estado': estado,
    };
  }
}

class AbonoCredito {
  final int idAbono;
  final int? idCliente;
  final String nombreCliente;
  final double monto;
  final String metodoPago;
  final double saldoAnterior;
  final double saldoRestante;
  final String? comprobanteNumero;
  final String? notas;
  final String? usuarioRegistro;
  final DateTime fechaAbono;

  AbonoCredito({
    required this.idAbono,
    this.idCliente,
    required this.nombreCliente,
    required this.monto,
    required this.metodoPago,
    required this.saldoAnterior,
    required this.saldoRestante,
    this.comprobanteNumero,
    this.notas,
    this.usuarioRegistro,
    required this.fechaAbono,
  });

  factory AbonoCredito.fromJson(Map<String, dynamic> json) {
    return AbonoCredito(
      idAbono: (json['idAbono'] as num?)?.toInt() ?? 0,
      idCliente: (json['idCliente'] as num?)?.toInt(),
      nombreCliente: json['nombreCliente'] as String? ?? '',
      monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
      metodoPago: json['metodoPago'] as String? ?? 'Efectivo',
      saldoAnterior: (json['saldoAnterior'] as num?)?.toDouble() ?? 0.0,
      saldoRestante: (json['saldoRestante'] as num?)?.toDouble() ?? 0.0,
      comprobanteNumero: json['comprobanteNumero'] as String?,
      notas: json['notas'] as String?,
      usuarioRegistro: json['usuarioRegistro'] as String?,
      fechaAbono: json['fechaAbono'] != null
          ? DateTime.tryParse(json['fechaAbono']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class EstadoCuentaCliente {
  final Cliente cliente;
  final double totalVentasCredito;
  final double totalAbonosRealizados;
  final List<dynamic> comprasCreditoRecientes;
  final List<AbonoCredito> abonosRecientes;

  EstadoCuentaCliente({
    required this.cliente,
    required this.totalVentasCredito,
    required this.totalAbonosRealizados,
    required this.comprasCreditoRecientes,
    required this.abonosRecientes,
  });

  factory EstadoCuentaCliente.fromJson(Map<String, dynamic> json) {
    return EstadoCuentaCliente(
      cliente: Cliente.fromJson(json['cliente'] as Map<String, dynamic>),
      totalVentasCredito: (json['totalVentasCredito'] as num?)?.toDouble() ?? 0.0,
      totalAbonosRealizados: (json['totalAbonosRealizados'] as num?)?.toDouble() ?? 0.0,
      comprasCreditoRecientes: (json['comprasCreditoRecientes'] as List<dynamic>?) ?? [],
      abonosRecientes: (json['abonosRecientes'] as List<dynamic>?)
              ?.map((e) => AbonoCredito.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ResumenCreditos {
  final int totalClientes;
  final int clientesConDeuda;
  final double totalSaldoDeudor;
  final double totalAbonosMes;

  ResumenCreditos({
    required this.totalClientes,
    required this.clientesConDeuda,
    required this.totalSaldoDeudor,
    required this.totalAbonosMes,
  });

  double get totalDeuda => totalSaldoDeudor;

  factory ResumenCreditos.fromJson(Map<String, dynamic> json) {
    return ResumenCreditos(
      totalClientes: (json['totalClientes'] as num?)?.toInt() ?? 0,
      clientesConDeuda: (json['clientesConDeuda'] as num?)?.toInt() ?? 0,
      totalSaldoDeudor: (json['totalSaldoDeudor'] as num?)?.toDouble() ?? 0.0,
      totalAbonosMes: (json['totalAbonosMes'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
