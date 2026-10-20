import 'dart:convert';

/// Servicio de formateo y generación de tickets para impresoras térmicas ESC/POS (58mm y 80mm).
/// Prepara el texto y bytes con alineaciones monoespacio, sanitización de caracteres y comandos estándar.
class ThermalTicketService {
  /// Ancho estándar de papel: 58mm = 32 columnas | 80mm = 48 columnas
  static const int width58mm = 32;
  static const int width80mm = 48;

  /// Sanitiza el texto reemplazando tildes y caracteres especiales para evitar
  /// impresión de caracteres corruptos en impresoras térmicas de tabla CP437/ASCII básica.
  static String sanitize(String input) {
    return input
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'U')
        .replaceAll('ñ', 'n')
        .replaceAll('Ñ', 'N')
        .replaceAll('¡', '')
        .replaceAll('¿', '')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '') // Solo caracteres ASCII imprimibles
        .trim();
  }

  /// Centra una línea de texto en el ancho especificado
  static String center(String text, [int width = width58mm]) {
    final clean = sanitize(text);
    if (clean.length >= width) return clean.substring(0, width);
    final totalPad = width - clean.length;
    final padLeft = totalPad ~/ 2;
    final padRight = totalPad - padLeft;
    return ' ' * padLeft + clean + ' ' * padRight;
  }

  /// Genera una línea divisoria (ej. --------------------------------)
  static String divider([int width = width58mm, String char = '-']) {
    return char * width;
  }

  /// Formatea una línea con dos columnas: izquierda (justificada a la izq) y derecha (justificada a la der)
  static String twoColumns(String left, String right, [int width = width58mm]) {
    final cleanLeft = sanitize(left);
    String cleanRight = sanitize(right);

    if (cleanRight.length >= width) {
      cleanRight = cleanRight.substring(0, width - 1);
    }

    final maxLeftLen = width - cleanRight.length - 1;
    final safeLeft = (cleanLeft.length > maxLeftLen && maxLeftLen > 0)
        ? cleanLeft.substring(0, maxLeftLen)
        : (maxLeftLen <= 0 ? '' : cleanLeft);

    final spaces = width - safeLeft.length - cleanRight.length;
    final pad = spaces > 0 ? ' ' * spaces : ' ';
    return safeLeft + pad + cleanRight;
  }

  /// Genera el texto completo del comprobante de venta en formato texto monoespacio
  static String generateReceiptText({
    required int? ticketId,
    required String clienteNombre,
    required String? clienteDocumento,
    required String metodoPago,
    required List<TicketItem> items,
    required double total,
    double? pagadoCon,
    double? vuelto,
    String? cajero,
    DateTime? fecha,
    int width = width58mm,
    String nombreComercio = 'CajaYa POS',
    String? rucDni,
    String? direccion = 'Av. Principal 123 - Lima',
    String? telefono = 'Tel: 987 654 321',
    String? lemaComercial,
    String? tipoComprobante,
    String? serieCorrelativo,
    String? estadoSunat,
    String? sunatHash,
    String? regimenTributario,
  }) {
    final buffer = StringBuffer();
    final fechaVenta = fecha ?? DateTime.now();
    final d = fechaVenta;
    final dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

    // Cabecera de la Bodega (Nivel 1 & 2)
    if (nombreComercio.isNotEmpty) {
      buffer.writeln(center(nombreComercio, width));
    }
    if (lemaComercial != null && lemaComercial.isNotEmpty) {
      buffer.writeln(center('"$lemaComercial"', width));
    }
    if (rucDni != null && rucDni.isNotEmpty) {
      buffer.writeln(center('RUC/DNI: $rucDni', width));
    }
    if (regimenTributario != null && regimenTributario.isNotEmpty) {
      final regLabel = switch (regimenTributario) {
        'NUEVO_RUS' => 'Regimen: NUEVO RUS',
        'RER' => 'Regimen: ESP. RENTA (RER)',
        'MYPE_TRIBUTARIO' => 'Regimen: MYPE TRIBUTARIO',
        'REGIMEN_GENERAL' => 'Regimen: GENERAL',
        _ => 'Regimen: $regimenTributario',
      };
      buffer.writeln(center(regLabel, width));
    }
    if (direccion != null && direccion.isNotEmpty) {
      buffer.writeln(center(direccion, width));
    }
    if (telefono != null && telefono.isNotEmpty) {
      buffer.writeln(center(telefono, width));
    }
    buffer.writeln(divider(width, '='));

    // Datos del Comprobante
    final bool esBoleta = tipoComprobante == 'BOLETA_ELECTRONICA' || tipoComprobante == 'BOLETA';
    final bool esFactura = tipoComprobante == 'FACTURA_ELECTRONICA';
    final bool esSunat = esBoleta || esFactura;

    if (esBoleta) {
      buffer.writeln(center('BOLETA DE VENTA', width));
      if (serieCorrelativo != null && serieCorrelativo.isNotEmpty) {
        buffer.writeln(twoColumns('SERIE-CORRELATIVO:', serieCorrelativo, width));
      }
    } else if (esFactura) {
      buffer.writeln(center('FACTURA ELECTRONICA', width));
      buffer.writeln(twoColumns('SERIE-CORRELATIVO:', serieCorrelativo ?? 'F001-00000001', width));
    } else {
      final ticketNum = ticketId != null ? '#${ticketId.toString().padLeft(6, '0')}' : 'TICKET DE VENTA';
      buffer.writeln(twoColumns('COMPROBANTE:', ticketNum, width));
    }

    if (esSunat && estadoSunat != null && estadoSunat.isNotEmpty) {
      buffer.writeln(twoColumns('ESTADO SUNAT:', estadoSunat, width));
    }

    buffer.writeln(twoColumns('FECHA:', dateStr, width));
    if (cajero != null && cajero.isNotEmpty) {
      buffer.writeln(twoColumns('CAJERO:', cajero, width));
    }

    final docCli = (clienteDocumento != null && clienteDocumento.isNotEmpty && clienteDocumento != '00000000')
        ? clienteDocumento
        : null;
    buffer.writeln(twoColumns('CLIENTE:', clienteNombre, width));
    if (docCli != null) {
      final docLabel = docCli.length == 11 ? 'RUC:' : (docCli.length == 8 ? 'DNI:' : 'DOC:');
      buffer.writeln(twoColumns(docLabel, docCli, width));
    }
    buffer.writeln(divider(width, '-'));

    // Encabezado de Productos (CANT  DESCRIPCION  TOTAL)
    if (width == width58mm) {
      buffer.writeln('CANT  DESCRIPCION         IMPORTE');
    } else {
      buffer.writeln('CANT  DESCRIPCION                                IMPORTE');
    }
    buffer.writeln(divider(width, '-'));

    // Lista de ítems vendidos
    for (final item in items) {
      final cantStr = item.cantidad.toStringAsFixed(item.cantidad.truncateToDouble() == item.cantidad ? 0 : 2);
      final precioStr = 'S/ ${item.subtotal.toStringAsFixed(2)}';
      final desc = item.nombre;

      final leftSide = '$cantStr x $desc';
      buffer.writeln(twoColumns(leftSide, precioStr, width));
    }

    buffer.writeln(divider(width, '='));

    // Totales y Liquidación de Pago
    // Nota Tributaria: En el Nuevo RUS la ley prohíbe discriminar IGV (el precio es precio cerrado al consumidor)
    if (esFactura && regimenTributario != 'NUEVO_RUS') {
      final opGravada = total / 1.18;
      final igv = total - opGravada;
      buffer.writeln(twoColumns('OP. GRAVADA:', 'S/ ${opGravada.toStringAsFixed(2)}', width));
      buffer.writeln(twoColumns('I.G.V. (18%):', 'S/ ${igv.toStringAsFixed(2)}', width));
    }
    buffer.writeln(twoColumns('TOTAL A PAGAR:', 'S/ ${total.toStringAsFixed(2)}', width));
    buffer.writeln(twoColumns('METODO DE PAGO:', metodoPago.toUpperCase(), width));

    if (metodoPago.toLowerCase().contains('efectivo')) {
      final recibido = pagadoCon ?? total;
      final cambio = vuelto ?? (recibido - total).clamp(0.0, 999999.0);
      buffer.writeln(twoColumns('IMPORTE RECIBIDO:', 'S/ ${recibido.toStringAsFixed(2)}', width));
      buffer.writeln(twoColumns('VUELTO / CAMBIO:', 'S/ ${cambio.toStringAsFixed(2)}', width));
    }

    buffer.writeln(divider(width, '-'));

    // Pie de Ticket y Agradecimiento
    if (esSunat) {
      if (sunatHash != null && sunatHash.trim().isNotEmpty) {
        final shortHash = sunatHash.trim().length > 16 ? '${sunatHash.trim().substring(0, 16)}...' : sunatHash.trim();
        buffer.writeln(twoColumns('HASH SUNAT:', shortHash, width));
      }
      buffer.writeln(center('Representacion impresa de la', width));
      buffer.writeln(center(esFactura ? 'FACTURA ELECTRONICA' : 'BOLETA DE VENTA ELECTRONICA', width));
      buffer.writeln(center('Autorizado mediante Resolucion SUNAT', width));
      buffer.writeln(divider(width, '-'));
    }
    buffer.writeln(center('¡Gracias por su compra!', width));
    buffer.writeln(center('Conserve su comprobante', width));
    buffer.writeln(center('CajaYa Cloud POS', width));
    buffer.writeln(); // Avance de papel

    return buffer.toString();
  }

  /// Genera los bytes nativos con secuencias de escape ESC/POS estándar
  /// listos para ser enviados mediante Bluetooth, USB o Red a cualquier impresora térmica.
  static List<int> generateEscPosBytes({
    required int? ticketId,
    required String clienteNombre,
    required String? clienteDocumento,
    required String metodoPago,
    required List<TicketItem> items,
    required double total,
    double? pagadoCon,
    double? vuelto,
    String? cajero,
    DateTime? fecha,
    int width = width58mm,
    String nombreComercio = 'CajaYa POS',
    String? rucDni,
    String? direccion = 'Av. Principal 123 - Lima',
    String? telefono = 'Tel: 987 654 321',
    String? lemaComercial,
    String? tipoComprobante,
    String? serieCorrelativo,
    String? estadoSunat,
    String? sunatHash,
    String? regimenTributario,
  }) {
    final List<int> bytes = [];

    // 1. Inicializar impresora (ESC @)
    bytes.addAll([0x1B, 0x40]);

    // 2. Establecer alineación centrada para encabezado (ESC a 1)
    bytes.addAll([0x1B, 0x61, 0x01]);

    // 3. Negrita activada (ESC E 1) y Doble Altura (ESC ! 16) para el título
    bytes.addAll([0x1B, 0x45, 0x01, 0x1B, 0x21, 0x10]);
    bytes.addAll(utf8.encode('${sanitize(nombreComercio)}\n'));

    // 4. Restaurar fuente normal (ESC ! 0) y negrita desactivada (ESC E 0)
    bytes.addAll([0x1B, 0x21, 0x00, 0x1B, 0x45, 0x00]);

    // 5. Contenido completo del ticket
    final receiptText = generateReceiptText(
      ticketId: ticketId,
      clienteNombre: clienteNombre,
      clienteDocumento: clienteDocumento,
      metodoPago: metodoPago,
      items: items,
      total: total,
      pagadoCon: pagadoCon,
      vuelto: vuelto,
      cajero: cajero,
      fecha: fecha,
      width: width,
      nombreComercio: '', // Ya impreso arriba en grande
      rucDni: rucDni,
      direccion: direccion,
      telefono: telefono,
      lemaComercial: lemaComercial,
      tipoComprobante: tipoComprobante,
      serieCorrelativo: serieCorrelativo,
      estadoSunat: estadoSunat,
      sunatHash: sunatHash,
      regimenTributario: regimenTributario,
    );

    // Volver a alineación izquierda (ESC a 0)
    bytes.addAll([0x1B, 0x61, 0x00]);
    bytes.addAll(utf8.encode(receiptText));

    // 6. Avance de 4 líneas de papel (ESC d 4)
    bytes.addAll([0x1B, 0x64, 0x04]);

    // 7. Corte de papel parcial/total si la impresora lo soporta (GS V 66 0)
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);

    return bytes;
  }
}

/// Modelo de ítem para impresión de tickets
class TicketItem {
  final String nombre;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;

  TicketItem({
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });
}
