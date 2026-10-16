class Proveedor {
  final int? idProveedor;
  final String ruc;
  final String razonSocial;
  final String? direccion;
  final String? telefono;
  final bool estado;

  Proveedor({
    this.idProveedor,
    required this.ruc,
    required this.razonSocial,
    this.direccion,
    this.telefono,
    this.estado = true,
  });

  factory Proveedor.fromJson(Map<String, dynamic> json) {
    return Proveedor(
      idProveedor: (json['idProveedor'] as num?)?.toInt(),
      ruc: json['ruc'] as String? ?? '',
      razonSocial: json['razonSocial'] as String? ?? '',
      direccion: json['direccion'] as String?,
      telefono: json['telefono'] as String?,
      estado: json['estado'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (idProveedor != null) 'idProveedor': idProveedor,
      'ruc': ruc,
      'razonSocial': razonSocial,
      if (direccion != null && direccion!.isNotEmpty) 'direccion': direccion,
      if (telefono != null && telefono!.isNotEmpty) 'telefono': telefono,
      'estado': estado,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Proveedor &&
          runtimeType == other.runtimeType &&
          idProveedor == other.idProveedor;

  @override
  int get hashCode => idProveedor.hashCode;
}
