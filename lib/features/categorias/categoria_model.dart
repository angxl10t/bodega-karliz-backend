class Categoria {
  final int idCategoria;
  final String nombre;
  final String? descripcion;
  final bool estado;

  Categoria({
    required this.idCategoria,
    required this.nombre,
    this.descripcion,
    this.estado = true,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      idCategoria: (json['idCategoria'] as num?)?.toInt() ?? 0,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      estado: json['estado'] as bool? ?? true,
    );
  }
}
