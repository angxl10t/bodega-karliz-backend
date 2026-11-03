class GarantiaBotella {
  final int idGarantia;
  final int? idBodega;
  final int? idCliente;
  final String nombrePersona;
  final String? telefono;
  final int cantidadBotellas;
  final double montoGarantia;
  final String tipoBotella;
  final String? notas;
  final String estado; // PENDIENTE, DEVUELTO, CANCELADO
  final int botellasDevueltas;
  final double montoDevuelto;
  final int botellasRestantes;
  final double montoRestante;
  final DateTime? fechaRegistro;
  final DateTime? fechaDevolucion;
  final String? usuarioRegistro;

  const GarantiaBotella({
    required this.idGarantia,
    this.idBodega,
    this.idCliente,
    required this.nombrePersona,
    this.telefono,
    this.cantidadBotellas = 1,
    this.montoGarantia = 0.0,
    this.tipoBotella = 'Botellas de Vidrio',
    this.notas,
    this.estado = 'PENDIENTE',
    this.botellasDevueltas = 0,
    this.montoDevuelto = 0.0,
    this.botellasRestantes = 1,
    this.montoRestante = 0.0,
    this.fechaRegistro,
    this.fechaDevolucion,
    this.usuarioRegistro,
  });

  bool get estaPendiente => estado.toUpperCase() == 'PENDIENTE';
  bool get estaDevuelto => estado.toUpperCase() == 'DEVUELTO';

  factory GarantiaBotella.fromJson(Map<String, dynamic> json) {
    final cant = (json['cantidadBotellas'] as num?)?.toInt() ?? 1;
    final bDevueltas = (json['botellasDevueltas'] as num?)?.toInt() ?? 0;
    final bRestantes =
        (json['botellasRestantes'] as num?)?.toInt() ??
        (cant - bDevueltas).clamp(0, cant);

    final mGarantia = (json['montoGarantia'] as num?)?.toDouble() ?? 0.0;
    final mDevuelto = (json['montoDevuelto'] as num?)?.toDouble() ?? 0.0;
    final mRestante =
        (json['montoRestante'] as num?)?.toDouble() ??
        (mGarantia - mDevuelto).clamp(0.0, mGarantia);

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return GarantiaBotella(
      idGarantia: (json['idGarantia'] as num?)?.toInt() ?? 0,
      idBodega: (json['idBodega'] as num?)?.toInt(),
      idCliente: (json['idCliente'] as num?)?.toInt(),
      nombrePersona: json['nombrePersona']?.toString() ?? 'Cliente',
      telefono: json['telefono']?.toString(),
      cantidadBotellas: cant,
      montoGarantia: mGarantia,
      tipoBotella: json['tipoBotella']?.toString() ?? 'Botellas de Vidrio',
      notas: json['notas']?.toString(),
      estado: json['estado']?.toString() ?? 'PENDIENTE',
      botellasDevueltas: bDevueltas,
      montoDevuelto: mDevuelto,
      botellasRestantes: bRestantes,
      montoRestante: mRestante,
      fechaRegistro: parseDate(json['fechaRegistro']),
      fechaDevolucion: parseDate(json['fechaDevolucion']),
      usuarioRegistro: json['usuarioRegistro']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idGarantia': idGarantia,
      'idBodega': idBodega,
      'idCliente': idCliente,
      'nombrePersona': nombrePersona,
      'telefono': telefono,
      'cantidadBotellas': cantidadBotellas,
      'montoGarantia': montoGarantia,
      'tipoBotella': tipoBotella,
      'notas': notas,
      'estado': estado,
      'botellasDevueltas': botellasDevueltas,
      'montoDevuelto': montoDevuelto,
      'botellasRestantes': botellasRestantes,
      'montoRestante': montoRestante,
      'fechaRegistro': fechaRegistro?.toIso8601String(),
      'fechaDevolucion': fechaDevolucion?.toIso8601String(),
      'usuarioRegistro': usuarioRegistro,
    };
  }
}

class ResumenGarantias {
  final double totalDineroCustodia;
  final int botellasPendientes;
  final int personasPendientes;
  final double totalDevueltoMes;
  final int botellasDevueltasMes;

  const ResumenGarantias({
    this.totalDineroCustodia = 0.0,
    this.botellasPendientes = 0,
    this.personasPendientes = 0,
    this.totalDevueltoMes = 0.0,
    this.botellasDevueltasMes = 0,
  });

  factory ResumenGarantias.fromJson(Map<String, dynamic> json) {
    return ResumenGarantias(
      totalDineroCustodia:
          (json['totalDineroCustodia'] as num?)?.toDouble() ?? 0.0,
      botellasPendientes: (json['botellasPendientes'] as num?)?.toInt() ?? 0,
      personasPendientes: (json['personasPendientes'] as num?)?.toInt() ?? 0,
      totalDevueltoMes: (json['totalDevueltoMes'] as num?)?.toDouble() ?? 0.0,
      botellasDevueltasMes:
          (json['botellasDevueltasMes'] as num?)?.toInt() ?? 0,
    );
  }
}
