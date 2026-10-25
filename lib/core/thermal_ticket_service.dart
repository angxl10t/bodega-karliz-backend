import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'configuracion_ticket_service.dart';

/// Resultado del intento de impresión térmica
class PrintResult {
  final bool exito;
  final String mensaje;
  final bool necesitaRawBt;

  const PrintResult({
    required this.exito,
    required this.mensaje,
    this.necesitaRawBt = false,
  });
}

/// Servicio de formateo y generación de tickets para impresoras térmicas ESC/POS (58mm y 80mm).
/// Prepara el texto y bytes con alineaciones monoespacio, sanitización de caracteres,
/// comandos de apertura de cajón monedero, códigos QR de Yape/Plin/SUNAT y dispatch directo.
class ThermalTicketService {
  /// Ancho estándar de papel: 58mm = 32 columnas | 80mm = 48 columnas
  static const int width58mm = 32;
  static const int width80mm = 48;

  /// Pulso ESC/POS para abrir gaveta de dinero (Pin 2 y Pin 5: ESC p 0 25 250)
  static List<int> get openDrawerBytes => const [
        0x1B, 0x70, 0x00, 0x19, 0xFA, // Pin 2
        0x1B, 0x70, 0x01, 0x19, 0xFA, // Pin 5
      ];

  /// Comando de corte parcial / total de papel (GS V 66 0)
  static List<int> get cutPaperBytes => const [
        0x1D, 0x56, 0x42, 0x00,
      ];

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

  /// Genera la secuencia binaria estándar ESC/POS para imprimir un código QR (GS ( k)
  /// Compatible con impresoras térmicas Epson, Xprinter, Sunmi, Goojprt y Zjiang.
  static List<int> generateEscPosQrBytes(String qrData, {int moduleSize = 5}) {
    if (qrData.trim().isEmpty) return [];
    final List<int> qrBytes = [];
    final data = utf8.encode(qrData.trim());
    final dataLen = data.length + 3;
    final pL = dataLen % 256;
    final pH = dataLen ~/ 256;

    // 1. Alineación Centrada para el QR (ESC a 1)
    qrBytes.addAll([0x1B, 0x61, 0x01]);

    // 2. Seleccionar modelo QR (Modelo 2 estándar: GS ( k 4 0 49 65 50 0)
    qrBytes.addAll([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);

    // 3. Ajustar tamaño del módulo de punto (GS ( k 3 0 49 67 size)
    qrBytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, moduleSize.clamp(3, 8)]);

    // 4. Ajustar nivel de corrección de error (Nivel M = 15%: GS ( k 3 0 49 69 49)
    qrBytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);

    // 5. Almacenar datos del código QR en el buffer de la impresora
    qrBytes.addAll([0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30]);
    qrBytes.addAll(data);

    // 6. Imprimir el código QR almacenado (GS ( k 3 0 49 81 48)
    qrBytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);

    // 7. Salto de línea y volver a alineación izquierda
    qrBytes.addAll([0x0A, 0x1B, 0x61, 0x00]);

    return qrBytes;
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
    ConfiguracionTicket? configTicket,
  }) {
    final cfg = configTicket ?? ConfiguracionTicketService.actual;
    final buffer = StringBuffer();
    final fechaVenta = fecha ?? DateTime.now();
    final d = fechaVenta;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

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

    // Información SUNAT si aplica
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

    // Código QR de Cobro / SUNAT (Pie de Ticket)
    if (cfg.mostrarQr) {
      final qrType = cfg.tipoQr.toUpperCase();
      final qrData = cfg.numeroQr.trim().isNotEmpty ? cfg.numeroQr.trim() : (telefono ?? '');

      if (qrType == 'YAPE' || qrType == 'PLIN') {
        buffer.writeln(center('PAGA CON $qrType ESCANEANDO:', width));
        if (qrData.isNotEmpty) {
          buffer.writeln(center('Numero: $qrData', width));
        }
        if (cfg.titularQr.trim().isNotEmpty) {
          buffer.writeln(center('Titular: ${cfg.titularQr.trim()}', width));
        }
        // Etiqueta interpretable por RawBT / drivers térmicos
        buffer.writeln(center('[qr]$qrData[/qr]', width));
        buffer.writeln(divider(width, '-'));
      } else if (qrType == 'SUNAT' && esSunat) {
        buffer.writeln(center('[qr:SUNAT-VERIFY][/qr]', width));
        buffer.writeln(divider(width, '-'));
      }
    }

    // Pie de Ticket Personalizado
    if (cfg.mensajeAgradecimiento.isNotEmpty) {
      buffer.writeln(center(cfg.mensajeAgradecimiento, width));
    }
    if (cfg.mensajeSecundario.isNotEmpty) {
      buffer.writeln(center(cfg.mensajeSecundario, width));
    }
    if (cfg.horarioAtencion.isNotEmpty) {
      buffer.writeln(center(cfg.horarioAtencion, width));
    }
    if (cfg.redesSociales.isNotEmpty) {
      buffer.writeln(center(cfg.redesSociales, width));
    }
    buffer.writeln(center('CajaYa Cloud POS', width));
    buffer.writeln(); // Avance de papel

    return buffer.toString();
  }

  /// Genera los bytes nativos con secuencias de escape ESC/POS estándar
  /// listos para ser enviados mediante Bluetooth SPP/BLE, USB o Red a cualquier impresora térmica.
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
    ConfiguracionTicket? configTicket,
    bool? forzarAperturaGaveta,
  }) {
    final cfg = configTicket ?? ConfiguracionTicketService.actual;
    final List<int> bytes = [];

    // 1. Apertura de gaveta de dinero si está configurado o forzado
    final bool debeAbrirGaveta = forzarAperturaGaveta ??
        (cfg.abrirGaveta && metodoPago.toLowerCase().contains('efectivo'));
    if (debeAbrirGaveta) {
      bytes.addAll(openDrawerBytes);
    }

    // 2. Inicializar impresora (ESC @)
    bytes.addAll([0x1B, 0x40]);

    // 3. Establecer alineación centrada para encabezado (ESC a 1)
    bytes.addAll([0x1B, 0x61, 0x01]);

    // 4. Negrita activada (ESC E 1) y Doble Altura (ESC ! 16) para el nombre del comercio
    bytes.addAll([0x1B, 0x45, 0x01, 0x1B, 0x21, 0x10]);
    bytes.addAll(utf8.encode('${sanitize(nombreComercio)}\n'));

    // 5. Restaurar fuente normal (ESC ! 0) y negrita desactivada (ESC E 0)
    bytes.addAll([0x1B, 0x21, 0x00, 0x1B, 0x45, 0x00]);

    // 6. Contenido del comprobante formateado
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
      configTicket: cfg,
    );

    // Volver a alineación izquierda (ESC a 0)
    bytes.addAll([0x1B, 0x61, 0x00]);
    bytes.addAll(utf8.encode(receiptText));

    // 7. Si hay código QR activo, imprimir el código QR binario nativo ESC/POS
    if (cfg.mostrarQr) {
      final qrType = cfg.tipoQr.toUpperCase();
      String qrPayload = cfg.numeroQr.trim().isNotEmpty ? cfg.numeroQr.trim() : (telefono ?? '');

      if (qrType == 'YAPE') {
        qrPayload = 'https://yape.pe/p/$qrPayload';
      } else if (qrType == 'PLIN') {
        qrPayload = 'https://plin.pe/p/$qrPayload';
      } else if (qrType == 'SUNAT' && sunatHash != null && sunatHash.isNotEmpty) {
        qrPayload = '$rucDni|$tipoComprobante|${serieCorrelativo ?? ""}|$total|$sunatHash';
      }

      if (qrPayload.isNotEmpty) {
        final qrBytes = generateEscPosQrBytes(qrPayload, moduleSize: width == width58mm ? 4 : 6);
        bytes.addAll(qrBytes);
      }
    }

    // 8. Avance de 4 líneas de papel (ESC d 4)
    bytes.addAll([0x1B, 0x64, 0x04]);

    // 9. Corte de papel parcial / total (GS V 66 0)
    bytes.addAll(cutPaperBytes);

    return bytes;
  }

  /// Despacha la impresión directa al hardware (vía RawBT en móvil/web, servidor local HTTP o fallback)
  static Future<PrintResult> imprimirTicketDirecto({
    required List<int> escPosBytes,
    required String receiptText,
    ConfiguracionTicket? config,
  }) async {
    final cfg = config ?? ConfiguracionTicketService.actual;

    // Modo 1: RawBT (Bluetooth SPP/BLE, USB y Network)
    if (cfg.modoConexion == 'rawbt') {
      try {
        final b64 = base64Encode(escPosBytes);
        final rawbtUri = Uri.parse('rawbt:data:application/octet-stream;base64,$b64');

        final launched = await launchUrl(rawbtUri, mode: LaunchMode.externalApplication);
        if (launched) {
          return const PrintResult(
            exito: true,
            mensaje: 'Ticket enviado a la impresora térmica vía RawBT.',
          );
        }
      } catch (_) {}

      // Intentar fallback al servidor local de RawBT (http://127.0.0.1:40213/)
      try {
        final response = await http
            .post(
              Uri.parse(cfg.servidorLocalUrl),
              body: escPosBytes,
              headers: {'Content-Type': 'application/octet-stream'},
            )
            .timeout(const Duration(milliseconds: 1800));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return const PrintResult(
            exito: true,
            mensaje: 'Ticket impreso directamente vía RawBT Local Bridge.',
          );
        }
      } catch (_) {}

      return const PrintResult(
        exito: false,
        mensaje: 'No se detectó el servicio de impresión RawBT. Instala RawBT en Android o activa el servidor local.',
        necesitaRawBt: true,
      );
    }

    // Modo 2: Servidor Local HTTP de Impresión (ej. 127.0.0.1:40213 o IP de red local)
    if (cfg.modoConexion == 'servidor_local') {
      try {
        final response = await http
            .post(
              Uri.parse(cfg.servidorLocalUrl),
              body: escPosBytes,
              headers: {'Content-Type': 'application/octet-stream'},
            )
            .timeout(const Duration(seconds: 3));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return const PrintResult(
            exito: true,
            mensaje: 'Comando enviado con éxito al servidor local de impresión.',
          );
        } else {
          return PrintResult(
            exito: false,
            mensaje: 'El servidor local de impresión respondió con código ${response.statusCode}.',
          );
        }
      } catch (e) {
        return PrintResult(
          exito: false,
          mensaje: 'No se pudo conectar al servidor de impresión en ${cfg.servidorLocalUrl}. Revisa que esté activo.',
        );
      }
    }

    // Modo 3: Navegador Web / Fallback Estándar
    return const PrintResult(
      exito: true,
      mensaje: 'Ticket generado para vista o impresión desde el navegador.',
    );
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
