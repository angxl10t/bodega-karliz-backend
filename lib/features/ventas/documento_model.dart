class DniResponse {
  final String numero;
  final String nombreCompleto;
  final String? nombres;
  final String? apellidoPaterno;
  final String? apellidoMaterno;
  final bool encontrado;
  final String? mensaje;
  final String? fuente;

  DniResponse({
    required this.numero,
    required this.nombreCompleto,
    this.nombres,
    this.apellidoPaterno,
    this.apellidoMaterno,
    required this.encontrado,
    this.mensaje,
    this.fuente,
  });

  factory DniResponse.fromJson(Map<String, dynamic> json) {
    return DniResponse(
      numero: json['numero'] as String? ?? '',
      nombreCompleto: json['nombreCompleto'] as String? ?? '',
      nombres: json['nombres'] as String?,
      apellidoPaterno: json['apellidoPaterno'] as String?,
      apellidoMaterno: json['apellidoMaterno'] as String?,
      encontrado: json['encontrado'] as bool? ?? false,
      mensaje: json['mensaje'] as String?,
      fuente: json['fuente'] as String?,
    );
  }
}

class RucResponse {
  final String numero;
  final String razonSocial;
  final String estado;
  final String condicion;
  final String? direccion;
  final String? departamento;
  final String? provincia;
  final String? distrito;
  final String? ubigeo;
  final bool esActivo;
  final bool esHabido;
  final bool encontrado;
  final String? mensaje;
  final String? fuente;

  RucResponse({
    required this.numero,
    required this.razonSocial,
    required this.estado,
    required this.condicion,
    this.direccion,
    this.departamento,
    this.provincia,
    this.distrito,
    this.ubigeo,
    required this.esActivo,
    required this.esHabido,
    required this.encontrado,
    this.mensaje,
    this.fuente,
  });

  factory RucResponse.fromJson(Map<String, dynamic> json) {
    return RucResponse(
      numero: json['numero'] as String? ?? '',
      razonSocial: json['razonSocial'] as String? ?? '',
      estado: json['estado'] as String? ?? 'DESCONOCIDO',
      condicion: json['condicion'] as String? ?? 'DESCONOCIDO',
      direccion: json['direccion'] as String?,
      departamento: json['departamento'] as String?,
      provincia: json['provincia'] as String?,
      distrito: json['distrito'] as String?,
      ubigeo: json['ubigeo'] as String?,
      esActivo: json['esActivo'] as bool? ?? false,
      esHabido: json['esHabido'] as bool? ?? false,
      encontrado: json['encontrado'] as bool? ?? false,
      mensaje: json['mensaje'] as String?,
      fuente: json['fuente'] as String?,
    );
  }
}
