import '../../features/ventas/venta_model.dart';

/// Detalle individual de un producto vendido en modo offline
class OfflineVentaDetalle {
  final int idProducto;
  final String nombreProducto;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;
  final String? codigo;

  OfflineVentaDetalle({
    required this.idProducto,
    required this.nombreProducto,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    this.codigo,
  });

  Map<String, dynamic> toJson() => {
        'idProducto': idProducto,
        'nombreProducto': nombreProducto,
        'cantidad': cantidad,
        'precioUnitario': precioUnitario,
        'subtotal': subtotal,
        if (codigo != null) 'codigo': codigo,
      };

  factory OfflineVentaDetalle.fromJson(Map<String, dynamic> json) => OfflineVentaDetalle(
        idProducto: (json['idProducto'] as num).toInt(),
        nombreProducto: json['nombreProducto'] as String? ?? 'Producto',
        cantidad: (json['cantidad'] as num).toDouble(),
        precioUnitario: (json['precioUnitario'] as num).toDouble(),
        subtotal: (json['subtotal'] as num).toDouble(),
        codigo: json['codigo'] as String?,
      );

  VentaDetalleEnvio toVentaDetalleEnvio() => VentaDetalleEnvio(
        idProducto: idProducto,
        cantidad: cantidad,
      );

  VentaDetalleItem toVentaDetalleItem() => VentaDetalleItem(
        idProducto: idProducto,
        nombreProducto: nombreProducto,
        cantidad: cantidad,
        precioUnitario: precioUnitario,
        subtotal: subtotal,
      );
}

/// Registro inmutable de una venta emitida de forma local durante un corte de red.
/// Almacena todos los datos necesarios para firmar el ticket y sincronizarse con
/// el backend una vez recuperada la conexión a internet.
class OfflineVenta {
  final String uuid; // UUID v4 único (usado como idempotencyKey)
  final String localTicket; // Número identificador local (ej: TK-OFF-8392)
  final int idBodega;
  final int? idCliente;
  final String? clienteDocumento;
  final String clienteNombre;
  final String metodoPago;
  final String? tipoComprobante;
  final double? montoRecibido;
  final double? vuelto;
  final double total;
  final String? usuarioRegistro;
  final DateTime fechaCreacion;
  final List<OfflineVentaDetalle> detalles;

  // Estado y Trazabilidad de Sincronización
  String estadoSync; // 'PENDIENTE', 'SINCRONIZANDO', 'ERROR'
  int intentosSync;
  String? ultimoError;
  DateTime? fechaUltimoIntento;

  OfflineVenta({
    required this.uuid,
    required this.localTicket,
    required this.idBodega,
    this.idCliente,
    this.clienteDocumento,
    required this.clienteNombre,
    required this.metodoPago,
    this.tipoComprobante,
    this.montoRecibido,
    this.vuelto,
    required this.total,
    this.usuarioRegistro,
    required this.fechaCreacion,
    required this.detalles,
    this.estadoSync = 'PENDIENTE',
    this.intentosSync = 0,
    this.ultimoError,
    this.fechaUltimoIntento,
  });

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'localTicket': localTicket,
        'idBodega': idBodega,
        if (idCliente != null) 'idCliente': idCliente,
        if (clienteDocumento != null) 'clienteDocumento': clienteDocumento,
        'clienteNombre': clienteNombre,
        'metodoPago': metodoPago,
        if (tipoComprobante != null) 'tipoComprobante': tipoComprobante,
        if (montoRecibido != null) 'montoRecibido': montoRecibido,
        if (vuelto != null) 'vuelto': vuelto,
        'total': total,
        if (usuarioRegistro != null) 'usuarioRegistro': usuarioRegistro,
        'fechaCreacion': fechaCreacion.toIso8601String(),
        'detalles': detalles.map((d) => d.toJson()).toList(),
        'estadoSync': estadoSync,
        'intentosSync': intentosSync,
        if (ultimoError != null) 'ultimoError': ultimoError,
        if (fechaUltimoIntento != null) 'fechaUltimoIntento': fechaUltimoIntento!.toIso8601String(),
      };

  factory OfflineVenta.fromJson(Map<String, dynamic> json) => OfflineVenta(
        uuid: json['uuid'] as String,
        localTicket: json['localTicket'] as String? ?? 'TK-OFF-0000',
        idBodega: (json['idBodega'] as num?)?.toInt() ?? 0,
        idCliente: (json['idCliente'] as num?)?.toInt(),
        clienteDocumento: json['clienteDocumento'] as String?,
        clienteNombre: json['clienteNombre'] as String? ?? 'Público General',
        metodoPago: json['metodoPago'] as String? ?? 'Efectivo',
        tipoComprobante: json['tipoComprobante'] as String?,
        montoRecibido: (json['montoRecibido'] as num?)?.toDouble(),
        vuelto: (json['vuelto'] as num?)?.toDouble(),
        total: (json['total'] as num?)?.toDouble() ?? 0.0,
        usuarioRegistro: json['usuarioRegistro'] as String?,
        fechaCreacion: DateTime.tryParse(json['fechaCreacion'] as String? ?? '') ?? DateTime.now(),
        detalles: (json['detalles'] as List<dynamic>?)
                ?.map((d) => OfflineVentaDetalle.fromJson(d as Map<String, dynamic>))
                .toList() ??
            [],
        estadoSync: json['estadoSync'] as String? ?? 'PENDIENTE',
        intentosSync: (json['intentosSync'] as num?)?.toInt() ?? 0,
        ultimoError: json['ultimoError'] as String?,
        fechaUltimoIntento: json['fechaUltimoIntento'] != null
            ? DateTime.tryParse(json['fechaUltimoIntento'] as String)
            : null,
      );

  /// Construye el DTO que espera el endpoint POST /ventas del servidor
  VentaEnvio toVentaEnvio() => VentaEnvio(
        idCliente: idCliente,
        clienteDocumento: clienteDocumento,
        clienteNombre: clienteNombre,
        metodoPago: metodoPago,
        tipoComprobante: tipoComprobante,
        idempotencyKey: uuid,
        montoRecibido: montoRecibido,
        detalles: detalles.map((d) => d.toVentaDetalleEnvio()).toList(),
      );

  /// Convierte la venta offline en un modelo VentaRegistro para que la interfaz
  /// de usuario, diálogos de confirmación, boletas e impresoras puedan procesarla
  /// de forma transparente como si fuera una venta online.
  VentaRegistro toVentaRegistro() => VentaRegistro(
        idVenta: -1, // ID temporal negativo indica venta offline pendiente
        idCliente: idCliente,
        clienteDocumento: clienteDocumento,
        clienteNombre: clienteNombre,
        metodoPago: metodoPago,
        total: total,
        fechaVenta: fechaCreacion,
        usuarioRegistro: usuarioRegistro ?? 'Cajero Local',
        estado: 'COMPLETADA',
        tipoComprobante: tipoComprobante ?? 'NOTA_VENTA',
        serieCorrelativo: localTicket,
        estadoSunat: 'OFFLINE_PENDIENTE',
        sunatMensaje: 'Guardado localmente. Pendiente de sincronización automática.',
        detalles: detalles.map((d) => d.toVentaDetalleItem()).toList(),
      );
}
