import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'configuracion_ticket_service.dart';
import 'native_bluetooth_printer_service.dart';

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
/// comandos de apertura de cajón monedero, códigos QR de Yape/Plin/Catálogo Digital y dispatch directo.
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
  static List<int> get cutPaperBytes => const [0x1D, 0x56, 0x42, 0x00];

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
        .replaceAll(
          RegExp(r'[^\x20-\x7E]'),
          '',
        ) // Solo caracteres ASCII imprimibles
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

  /// Divide un texto largo en palabras respetando el ancho máximo y centra cada línea resultante.
  static String wrapCenter(String text, [int width = width58mm]) {
    final clean = sanitize(text);
    if (clean.isEmpty) return '';
    final paragraphs = clean.split('\n');
    final List<String> resultLines = [];

    for (final paragraph in paragraphs) {
      final pTrim = paragraph.trim();
      if (pTrim.isEmpty) continue;
      if (pTrim.length <= width) {
        resultLines.add(center(pTrim, width));
        continue;
      }

      final words = pTrim.split(RegExp(r'\s+'));
      String currentLine = '';

      for (final word in words) {
        if (word.isEmpty) continue;
        if (currentLine.isEmpty) {
          if (word.length <= width) {
            currentLine = word;
          } else {
            resultLines.add(center(word.substring(0, width), width));
            currentLine = word.substring(width);
          }
        } else if (currentLine.length + 1 + word.length <= width) {
          currentLine += ' $word';
        } else {
          resultLines.add(center(currentLine, width));
          currentLine = word;
        }
      }
      if (currentLine.isNotEmpty) {
        resultLines.add(center(currentLine, width));
      }
    }

    return resultLines.join('\n');
  }

  /// Divide texto en líneas por palabras con anchos específicos para la primera línea y subsiguientes.
  static List<String> _wrapTextWords(
    String text,
    int firstWidth,
    int nextWidth,
  ) {
    final clean = text.trim();
    if (clean.isEmpty) return [''];
    if (clean.length <= firstWidth) return [clean];

    final words = clean.split(RegExp(r'\s+'));
    final result = <String>[];
    String current = '';
    int targetWidth = firstWidth;

    for (final word in words) {
      if (word.isEmpty) continue;
      if (current.isEmpty) {
        if (word.length <= targetWidth) {
          current = word;
        } else {
          final cut = targetWidth;
          result.add(word.substring(0, cut));
          targetWidth = nextWidth;
          current = word.substring(cut);
        }
      } else if (current.length + 1 + word.length <= targetWidth) {
        current += ' $word';
      } else {
        result.add(current);
        targetWidth = nextWidth;
        current = word;
      }
    }
    if (current.isNotEmpty) {
      result.add(current);
    }
    return result;
  }

  /// Formatea la lista de productos con columnas estándar tipo boleta fiscal / retail:
  /// Cant. Desc. P.U. Imp.
  /// Envolviendo las descripciones largas e indentándolas limpiamente bajo Desc.
  static List<String> formatItemRows(
    List<TicketItem> items, [
    int width = width58mm,
  ]) {
    final List<String> lines = [];
    final bool is80mm = width >= width80mm;

    // Ancho de columnas según tipo de papel
    final int cantColWidth = is80mm ? 5 : 4;
    final int puColWidth = is80mm ? 8 : 7;
    final int impColWidth = is80mm ? 8 : 7;
    final int pricesTotalWidth = puColWidth + impColWidth;

    for (final item in items) {
      String cantStr = item.cantidad % 1 == 0
          ? item.cantidad.toInt().toString()
          : (item.cantidad * 100 % 1 == 0
                ? item.cantidad.toStringAsFixed(2)
                : item.cantidad.toStringAsFixed(3));

      final int cantFieldWidth = cantStr.length < cantColWidth
          ? cantColWidth
          : cantStr.length + 1;
      final String cantPadded = cantStr.padRight(cantFieldWidth);

      final double pu = item.precioUnitario > 0
          ? item.precioUnitario
          : (item.cantidad > 0 ? item.subtotal / item.cantidad : 0.0);
      final String puStr = 'S/${pu.toStringAsFixed(2)}'.padLeft(puColWidth);
      final String impStr = 'S/${item.subtotal.toStringAsFixed(2)}'.padLeft(
        impColWidth,
      );

      // Nombre completo del producto con variante si existe
      String descCompleta = sanitize(item.nombre);
      if (item.variante != null && item.variante!.trim().isNotEmpty) {
        descCompleta += ' ${sanitize(item.variante!)}';
      }

      final int descCol1Width = (width - cantFieldWidth - pricesTotalWidth)
          .clamp(4, width);
      final int descNextWidth = (width - cantFieldWidth).clamp(4, width);

      final descChunks = _wrapTextWords(
        descCompleta,
        descCol1Width,
        descNextWidth,
      );

      // Línea 1: Cantidad | Descripción | P.U. | Imp.
      final String desc1 = (descChunks.isNotEmpty ? descChunks.first : '')
          .padRight(descCol1Width);
      lines.add('$cantPadded$desc1$puStr$impStr');

      // Líneas subsiguientes indentadas
      final String indent = ' ' * cantFieldWidth;
      for (int i = 1; i < descChunks.length; i++) {
        lines.add('$indent${descChunks[i]}');
      }

      // Observaciones / notas
      if (item.notas != null && item.notas!.trim().isNotEmpty) {
        final notasChunks = _wrapTextWords(
          '(${sanitize(item.notas!.trim())})',
          descNextWidth,
          descNextWidth,
        );
        for (final n in notasChunks) {
          lines.add('$indent$n');
        }
      }
    }

    return lines;
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
    qrBytes.addAll([
      0x1D,
      0x28,
      0x6B,
      0x03,
      0x00,
      0x31,
      0x43,
      moduleSize.clamp(3, 8),
    ]);

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
    double? descuento,
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

    // 1. Cabecera Comercial y Fiscal (Centrada con wrapping limpio)
    if (nombreComercio.isNotEmpty) {
      buffer.writeln(center(sanitize(nombreComercio), width));
    }
    if (lemaComercial != null && lemaComercial.isNotEmpty) {
      buffer.writeln(wrapCenter('"$lemaComercial"', width));
    }
    final bool esInformal = regimenTributario == 'INFORMAL';
    if (!esInformal) {
      if (rucDni != null && rucDni.isNotEmpty) {
        final cleanRuc = sanitize(rucDni);
        if (cleanRuc.toUpperCase().startsWith('RUC') ||
            cleanRuc.toUpperCase().startsWith('DNI')) {
          buffer.writeln(center(cleanRuc, width));
        } else if (cleanRuc.length == 11) {
          buffer.writeln(center('RUC: $cleanRuc', width));
        } else if (cleanRuc.length == 8) {
          buffer.writeln(center('DNI: $cleanRuc', width));
        } else {
          buffer.writeln(center('RUC: $cleanRuc', width));
        }
      }
      if (regimenTributario != null &&
          regimenTributario.isNotEmpty &&
          regimenTributario != 'GENERAL' &&
          regimenTributario != 'INFORMAL') {
        buffer.writeln(center('Regimen: $regimenTributario', width));
      }
    }
    if (direccion != null && direccion.isNotEmpty) {
      buffer.writeln(wrapCenter(direccion, width));
    }
    if (telefono != null && telefono.isNotEmpty) {
      final cleanTel = sanitize(telefono);
      final telLabel =
          cleanTel.toLowerCase().startsWith('tel') ||
              cleanTel.toLowerCase().startsWith('telf')
          ? cleanTel
          : 'Telf: $cleanTel';
      buffer.writeln(center(telLabel, width));
    }
    if (cfg.redesSociales.isNotEmpty && cfg.redesSociales.contains('@')) {
      final cleanMail = sanitize(cfg.redesSociales);
      final mailLabel = cleanMail.toLowerCase().startsWith('email')
          ? cleanMail
          : 'Email: $cleanMail';
      buffer.writeln(center(mailLabel, width));
    }
    buffer.writeln(divider(width, '-'));

    // 2. Tipo de Comprobante y Serie-Correlativo
    final bool esBoleta =
        !esInformal &&
        (tipoComprobante == 'BOLETA_ELECTRONICA' ||
            tipoComprobante == 'BOLETA');
    final bool esFactura =
        !esInformal &&
        (tipoComprobante == 'FACTURA_ELECTRONICA' ||
            tipoComprobante == 'FACTURA');

    if (esBoleta) {
      buffer.writeln(center('BOLETA DE VENTA ELECTRONICA', width));
      final numStr = (serieCorrelativo != null && serieCorrelativo.isNotEmpty)
          ? serieCorrelativo
          : (ticketId != null
                ? 'B001-${ticketId.toString().padLeft(8, '0')}'
                : 'B001-00000001');
      buffer.writeln(center(numStr, width));
    } else if (esFactura) {
      buffer.writeln(center('FACTURA ELECTRONICA', width));
      final numStr = (serieCorrelativo != null && serieCorrelativo.isNotEmpty)
          ? serieCorrelativo
          : (ticketId != null
                ? 'F001-${ticketId.toString().padLeft(8, '0')}'
                : 'F001-00000001');
      buffer.writeln(center(numStr, width));
    } else {
      buffer.writeln(center('BOLETA DE VENTA', width));
      final numStr = (serieCorrelativo != null && serieCorrelativo.isNotEmpty)
          ? serieCorrelativo
          : (ticketId != null
                ? '#${ticketId.toString().padLeft(6, '0')}'
                : 'TICKET DE VENTA');
      buffer.writeln(center(numStr, width));
    }
    buffer.writeln(divider(width, '-'));

    // 3. Metadatos de Emisión y Cliente
    final fechaStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final horaStr =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
    buffer.writeln('Fecha Emision: $fechaStr');
    buffer.writeln('Hora Emision: $horaStr');

    final docCli =
        (clienteDocumento != null &&
            clienteDocumento.trim().isNotEmpty &&
            clienteDocumento.trim() != '00000000')
        ? clienteDocumento.trim()
        : null;

    final rawNombre =
        (clienteNombre.trim().isNotEmpty &&
            clienteNombre.trim() != 'Público General')
        ? clienteNombre.trim()
        : 'Clientes Varios';
    final cliNombre = sanitize(rawNombre);
    buffer.writeln('Cliente: $cliNombre');

    if (docCli != null) {
      if (docCli.length == 11) {
        buffer.writeln('RUC: $docCli');
      } else if (docCli.length == 8) {
        buffer.writeln('DNI: $docCli');
      } else {
        buffer.writeln('Doc: $docCli');
      }
    } else {
      buffer.writeln('Doc: 99999999');
    }

    if (cajero != null && cajero.trim().isNotEmpty) {
      buffer.writeln('Cajero: ${cajero.trim()}');
    }
    buffer.writeln(divider(width, '-'));

    // 4. Encabezado de Productos (Cant. Desc. P.U. Imp.)
    if (width == width58mm) {
      buffer.writeln('Cant. Desc.        P.U.   Imp.');
    } else {
      buffer.writeln('Cant. Desc.                     P.U.     Imp.');
    }
    buffer.writeln(divider(width, '-'));

    // 5. Lista de Ítems Formateada con P.U. e Imp.
    final itemLines = formatItemRows(items, width);
    for (final line in itemLines) {
      buffer.writeln(line);
    }
    buffer.writeln(divider(width, '-'));

    // 6. Totales y Liquidación de Pago
    if (descuento != null && descuento > 0.01) {
      final sub = total + descuento;
      buffer.writeln(
        twoColumns('SUBTOTAL:', 'S/ ${sub.toStringAsFixed(2)}', width),
      );
      buffer.writeln(
        twoColumns(
          'AHORRO EN PROMOS:',
          '-S/ ${descuento.toStringAsFixed(2)}',
          width,
        ),
      );
    }

    if (esBoleta || esFactura) {
      final opGravada = total / 1.18;
      final igv = total - opGravada;
      buffer.writeln(
        twoColumns('OP. GRAVADA:', 'S/ ${opGravada.toStringAsFixed(2)}', width),
      );
      buffer.writeln(
        twoColumns('I.G.V. (18%):', 'S/ ${igv.toStringAsFixed(2)}', width),
      );
    }

    buffer.writeln(
      twoColumns('TOTAL A PAGAR:', 'S/ ${total.toStringAsFixed(2)}', width),
    );
    buffer.writeln(divider(width, '-'));

    buffer.writeln(
      twoColumns('METODO DE PAGO:', metodoPago.toUpperCase(), width),
    );

    if (metodoPago.toLowerCase().contains('efectivo')) {
      final recibido = pagadoCon ?? total;
      final cambio = vuelto ?? (recibido - total).clamp(0.0, 999999.0);
      buffer.writeln(
        twoColumns(
          'IMPORTE RECIBIDO:',
          'S/ ${recibido.toStringAsFixed(2)}',
          width,
        ),
      );
      buffer.writeln(
        twoColumns(
          'VUELTO / CAMBIO:',
          'S/ ${cambio.toStringAsFixed(2)}',
          width,
        ),
      );
    } else {
      buffer.writeln(
        twoColumns('IMPORTE PAGADO:', 'S/ ${total.toStringAsFixed(2)}', width),
      );
    }
    buffer.writeln(divider(width, '-'));

    if (esBoleta || esFactura) {
      buffer.writeln(
        center('Representacion impresa de comprobante electronico', width),
      );
      if (sunatHash != null && sunatHash.isNotEmpty) {
        buffer.writeln(center('Res. SUNAT / Hash: $sunatHash', width));
      }
      buffer.writeln(divider(width, '-'));
    }

    // 7. Pie de Ticket Personalizado (Sin QR del negocio)
    if (cfg.mensajeAgradecimiento.isNotEmpty) {
      buffer.writeln(wrapCenter(cfg.mensajeAgradecimiento, width));
    }
    if (cfg.mensajeSecundario.isNotEmpty) {
      buffer.writeln(wrapCenter(cfg.mensajeSecundario, width));
    }
    if (cfg.horarioAtencion.isNotEmpty) {
      buffer.writeln(wrapCenter(cfg.horarioAtencion, width));
    }
    if (cfg.redesSociales.isNotEmpty && !cfg.redesSociales.contains('@')) {
      buffer.writeln(wrapCenter(cfg.redesSociales, width));
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
    double? descuento,
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
    final bool debeAbrirGaveta =
        forzarAperturaGaveta ??
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
      descuento: descuento,
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
      String qrPayload = cfg.numeroQr.trim().isNotEmpty
          ? cfg.numeroQr.trim()
          : (telefono ?? '');

      if (qrType == 'YAPE') {
        qrPayload = 'https://yape.pe/p/$qrPayload';
      } else if (qrType == 'PLIN') {
        qrPayload = 'https://plin.pe/p/$qrPayload';
      } else if (qrType == 'CATALOGO' || qrType == 'PERSONALIZADO') {
        // Enlace directo al catálogo digital o personalizado
      }

      if (qrPayload.isNotEmpty) {
        final qrBytes = generateEscPosQrBytes(
          qrPayload,
          moduleSize: width == width58mm ? 4 : 6,
        );
        bytes.addAll(qrBytes);
      }
    }

    // 8. Avance de 4 líneas de papel (ESC d 4)
    bytes.addAll([0x1B, 0x64, 0x04]);

    // 9. Corte de papel parcial / total (GS V 66 0)
    bytes.addAll(cutPaperBytes);

    return bytes;
  }

  /// Genera el texto monoespaciado para el comprobante de cobranza / abono de fiado
  static String generateAbonoReceiptText({
    required String comprobanteNumero,
    required String clienteNombre,
    required String? clienteDocumento,
    required double montoAbonado,
    required double saldoAnterior,
    required double saldoRestante,
    required String metodoPago,
    String? notas,
    String? cajero,
    DateTime? fecha,
    int width = width58mm,
    String nombreComercio = 'CajaYa POS',
    String? rucDni,
    String? direccion = 'Av. Principal 123 - Lima',
    String? telefono = 'Tel: 987 654 321',
    ConfiguracionTicket? configTicket,
  }) {
    final cfg = configTicket ?? ConfiguracionTicketService.actual;
    final buffer = StringBuffer();
    final d = fecha ?? DateTime.now();
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    // 1. Datos del Comercio
    if (nombreComercio.isNotEmpty) {
      buffer.writeln(center(nombreComercio.toUpperCase(), width));
    }
    if (rucDni != null && rucDni.isNotEmpty) {
      buffer.writeln(center(rucDni, width));
    }
    if (direccion != null && direccion.isNotEmpty) {
      buffer.writeln(center(direccion, width));
    }
    if (telefono != null && telefono.isNotEmpty) {
      buffer.writeln(center(telefono, width));
    }

    buffer.writeln(divider(width, '='));
    buffer.writeln(center('RECIBO DE ABONO / COBRANZA', width));
    buffer.writeln(center('CONTROL DE FIADOS Y DEUDAS', width));
    buffer.writeln(divider(width, '='));

    buffer.writeln(twoColumns('COMPROBANTE:', comprobanteNumero, width));
    buffer.writeln(twoColumns('FECHA:', dateStr, width));
    if (cajero != null && cajero.isNotEmpty) {
      buffer.writeln(twoColumns('COBRADO POR:', cajero, width));
    }
    buffer.writeln(divider(width, '-'));

    buffer.writeln(twoColumns('CLIENTE:', clienteNombre, width));
    if (clienteDocumento != null && clienteDocumento.isNotEmpty) {
      final docLabel = clienteDocumento.length == 8 ? 'DNI:' : 'DOC:';
      buffer.writeln(twoColumns(docLabel, clienteDocumento, width));
    }
    buffer.writeln(
      twoColumns('MEDIO DE PAGO:', metodoPago.toUpperCase(), width),
    );
    if (notas != null && notas.trim().isNotEmpty) {
      buffer.writeln(twoColumns('NOTAS:', notas.trim(), width));
    }
    buffer.writeln(divider(width, '-'));

    // Resumen de Deuda y Amortización
    buffer.writeln(
      twoColumns(
        'DEUDA ANTERIOR:',
        'S/ ${saldoAnterior.toStringAsFixed(2)}',
        width,
      ),
    );
    buffer.writeln(
      twoColumns(
        'MONTO ABONADO:',
        'S/ ${montoAbonado.toStringAsFixed(2)}',
        width,
      ),
    );
    buffer.writeln(divider(width, '-'));
    final estadoDeuda = saldoRestante <= 0.01
        ? 'DEUDA CANCELADA'
        : 'S/ ${saldoRestante.toStringAsFixed(2)}';
    buffer.writeln(twoColumns('SALDO PENDIENTE:', estadoDeuda, width));
    buffer.writeln(divider(width, '='));

    // Firma de conformidad
    buffer.writeln();
    buffer.writeln(center('________________________________', width));
    buffer.writeln(center('FIRMA / CONFORMIDAD CLIENTE', width));
    buffer.writeln();

    if (cfg.mensajeAgradecimiento.isNotEmpty) {
      buffer.writeln(center(cfg.mensajeAgradecimiento, width));
    }
    buffer.writeln(center('CajaYa Cloud POS', width));
    buffer.writeln();

    return buffer.toString();
  }

  /// Genera los bytes ESC/POS estándar para comprobantes térmicos de abono de crédito
  static List<int> generateAbonoEscPosBytes({
    required String comprobanteNumero,
    required String clienteNombre,
    required String? clienteDocumento,
    required double montoAbonado,
    required double saldoAnterior,
    required double saldoRestante,
    required String metodoPago,
    String? notas,
    String? cajero,
    DateTime? fecha,
    int width = width58mm,
    String nombreComercio = 'CajaYa POS',
    String? rucDni,
    String? direccion = 'Av. Principal 123 - Lima',
    String? telefono = 'Tel: 987 654 321',
    ConfiguracionTicket? configTicket,
    bool? forzarAperturaGaveta,
  }) {
    final cfg = configTicket ?? ConfiguracionTicketService.actual;
    final List<int> bytes = [];

    // 1. Abrir gaveta si el pago fue en efectivo
    final bool debeAbrirGaveta =
        forzarAperturaGaveta ??
        (cfg.abrirGaveta && metodoPago.toLowerCase().contains('efectivo'));
    if (debeAbrirGaveta) {
      bytes.addAll(openDrawerBytes);
    }

    // 2. Inicializar impresora (ESC @)
    bytes.addAll([0x1B, 0x40]);

    // 3. Encabezado en negrita y doble altura
    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll([0x1B, 0x45, 0x01, 0x1B, 0x21, 0x10]);
    bytes.addAll(utf8.encode('${sanitize(nombreComercio)}\n'));
    bytes.addAll([0x1B, 0x21, 0x00, 0x1B, 0x45, 0x00]);

    // 4. Contenido
    final abonoText = generateAbonoReceiptText(
      comprobanteNumero: comprobanteNumero,
      clienteNombre: clienteNombre,
      clienteDocumento: clienteDocumento,
      montoAbonado: montoAbonado,
      saldoAnterior: saldoAnterior,
      saldoRestante: saldoRestante,
      metodoPago: metodoPago,
      notas: notas,
      cajero: cajero,
      fecha: fecha,
      width: width,
      nombreComercio: '',
      rucDni: rucDni,
      direccion: direccion,
      telefono: telefono,
      configTicket: cfg,
    );

    bytes.addAll([0x1B, 0x61, 0x00]);
    bytes.addAll(utf8.encode(abonoText));

    // 5. Avance de papel y corte
    bytes.addAll([0x1B, 0x64, 0x04]);
    bytes.addAll(cutPaperBytes);

    return bytes;
  }

  /// Genera el texto del volante térmico promocional para entregar con el vuelto o la cuenta
  static String generateVolanteBarrioText({
    required String nombreComercio,
    required String urlCatalogo,
    String? lemaComercial,
    String? telefono,
    String? giroNegocio,
    int width = width58mm,
  }) {
    final buffer = StringBuffer();
    final giro = (giroNegocio ?? 'BODEGA').toUpperCase();
    final esGastronomico =
        giro == 'POLLERIA' ||
        giro == 'CHIFA' ||
        giro == 'FASTFOOD' ||
        giro == 'RESTAURANTE';

    buffer.writeln(divider(width, '='));
    buffer.writeln(center(nombreComercio.toUpperCase(), width));
    if (lemaComercial != null && lemaComercial.isNotEmpty) {
      buffer.writeln(center(lemaComercial, width));
    }
    buffer.writeln(divider(width, '='));
    buffer.writeln('');
    if (esGastronomico) {
      buffer.writeln(center('PIDE DESDE TU MESA O CASA!', width));
      buffer.writeln(center('Revisa nuestra carta digital', width));
      buffer.writeln(center('por WhatsApp y te lo preparamos.', width));
    } else {
      buffer.writeln(center('VECINO(A), NO HAGAS COLA!', width));
      buffer.writeln(center('Haz tus pedidos desde casa', width));
      buffer.writeln(center('por WhatsApp y te lo alistamos.', width));
    }
    buffer.writeln('');
    buffer.writeln(divider(width, '-'));
    buffer.writeln(
      center(
        esGastronomico
            ? 'ESCANEA NUESTRA CARTA DIGITAL:'
            : 'ESCANEA NUESTRA TIENDA VIRTUAL:',
        width,
      ),
    );
    buffer.writeln('[qr]$urlCatalogo[/qr]');
    if (urlCatalogo.length <= width) {
      buffer.writeln(center(urlCatalogo, width));
    } else {
      for (int i = 0; i < urlCatalogo.length; i += width) {
        final end = (i + width < urlCatalogo.length)
            ? i + width
            : urlCatalogo.length;
        buffer.writeln(center(urlCatalogo.substring(i, end), width));
      }
    }
    buffer.writeln(divider(width, '-'));
    buffer.writeln('');
    switch (giro) {
      case 'POLLERIA':
        buffer.writeln(center('* Pollo a la Brasa y Combos', width));
        buffer.writeln(center('* Papas, Cremas y Guarniciones', width));
        break;
      case 'CHIFA':
        buffer.writeln(center('* Chaufa al Wok y Aeropuertos', width));
        buffer.writeln(center('* Wantanes, Tipakay y Sopas', width));
        break;
      case 'FASTFOOD':
        buffer.writeln(center('* Hamburguesas y Salchipapas', width));
        buffer.writeln(center('* Broaster, Salsas y Bebidas', width));
        break;
      case 'RESTAURANTE':
        buffer.writeln(center('* Platos a la Carta y Menus', width));
        buffer.writeln(center('* Entradas, Postres y Refrescos', width));
        break;
      case 'BODEGA':
      default:
        buffer.writeln(center('* Abarrotes, Bebidas y Golosinas', width));
        buffer.writeln(center('* Promociones y Precios del Dia', width));
        break;
    }
    buffer.writeln(center('* Aceptamos Yape, Plin y Efectivo', width));
    buffer.writeln('');
    if (telefono != null && telefono.isNotEmpty) {
      buffer.writeln(center('Pedidos WhatsApp: $telefono', width));
    }
    buffer.writeln(divider(width, '='));
    if (esGastronomico) {
      buffer.writeln(center('Buen provecho y gracias!', width));
    } else {
      buffer.writeln(center('Gracias por apoyar a tu bodega!', width));
    }
    buffer.writeln(divider(width, '='));
    return buffer.toString();
  }

  /// Genera la secuencia binaria ESC/POS para imprimir el volante de barrio con código QR nativo
  static List<int> generateVolanteBarrioEscPosBytes({
    required String nombreComercio,
    required String urlCatalogo,
    String? lemaComercial,
    String? telefono,
    String? giroNegocio,
    int width = width58mm,
  }) {
    final List<int> bytes = [];
    // Reset / init
    bytes.addAll([0x1B, 0x40]);

    final text = generateVolanteBarrioText(
      nombreComercio: nombreComercio,
      urlCatalogo: urlCatalogo,
      lemaComercial: lemaComercial,
      telefono: telefono,
      giroNegocio: giroNegocio,
      width: width,
    );

    final lines = text.split('\n');
    for (final line in lines) {
      if (line.contains('[qr]')) {
        bytes.addAll(
          generateEscPosQrBytes(
            urlCatalogo,
            moduleSize: width == width58mm ? 5 : 7,
          ),
        );
      } else {
        bytes.addAll(utf8.encode('${sanitize(line)}\n'));
      }
    }

    // Avance de papel y corte
    bytes.addAll([0x1B, 0x64, 0x04]);
    bytes.addAll(cutPaperBytes);
    return bytes;
  }

  /// Genera el texto monoespaciado para la Boleta Consolidada Diaria del Nuevo RUS
  /// conforme al Art. 8 num 3.2 de la Res. de Superintendencia N° 007-99/SUNAT y Ley 30877.
  static String generateBoletaConsolidadaText({
    required String serieCorrelativo,
    required DateTime fechaEmision,
    required double montoTotal,
    required int cantidadOperaciones,
    String tipoEmision = 'TALONARIO_FISICO',
    String? observaciones,
    String? cajero,
    DateTime? fechaRegistro,
    int width = width58mm,
    String nombreComercio = 'CajaYa POS',
    String? rucDni,
    String? direccion = 'Av. Principal 123 - Lima',
    String? telefono = 'Tel: 987 654 321',
    String? lemaComercial,
  }) {
    final buffer = StringBuffer();
    final d = fechaEmision;
    final fechaStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final reg = fechaRegistro ?? DateTime.now();
    final regStr =
        '${reg.day.toString().padLeft(2, '0')}/${reg.month.toString().padLeft(2, '0')}/${reg.year} ${reg.hour.toString().padLeft(2, '0')}:${reg.minute.toString().padLeft(2, '0')}';

    // 1. Datos del Comercio
    if (nombreComercio.isNotEmpty) {
      buffer.writeln(center(nombreComercio.toUpperCase(), width));
    }
    if (lemaComercial != null && lemaComercial.isNotEmpty) {
      buffer.writeln(center('"$lemaComercial"', width));
    }
    if (rucDni != null && rucDni.isNotEmpty) {
      buffer.writeln(center('RUC: $rucDni', width));
    }
    buffer.writeln(center('Regimen: NUEVO RUS (Ley 30877)', width));
    if (direccion != null && direccion.isNotEmpty) {
      buffer.writeln(center(direccion, width));
    }
    if (telefono != null && telefono.isNotEmpty) {
      buffer.writeln(center(telefono, width));
    }

    buffer.writeln(divider(width, '='));
    buffer.writeln(center('BOLETA DE VENTA CONSOLIDADA', width));
    buffer.writeln(center('VENTAS MENORES A S/ 5.00', width));
    buffer.writeln(center('Res. SUNAT 007-99 Art. 8.3.2', width));
    buffer.writeln(divider(width, '='));

    buffer.writeln(twoColumns('BOLETA N°:', serieCorrelativo, width));
    buffer.writeln(twoColumns('FECHA VENTAS:', fechaStr, width));
    buffer.writeln(
      twoColumns(
        'TIPO EMISION:',
        tipoEmision == 'TALONARIO_FISICO'
            ? 'Talonario Fisico'
            : 'Digital CajaYa',
        width,
      ),
    );
    if (cajero != null && cajero.isNotEmpty) {
      buffer.writeln(twoColumns('REGISTRADO POR:', cajero, width));
    }
    buffer.writeln(twoColumns('FECHA REGISTRO:', regStr, width));
    buffer.writeln(divider(width, '-'));

    buffer.writeln(
      twoColumns('OPERACIONES:', '$cantidadOperaciones ventas', width),
    );
    buffer.writeln(twoColumns('TOPE UNITARIO:', '<= S/ 5.00 c/u', width));
    buffer.writeln(divider(width, '-'));
    buffer.writeln(
      twoColumns(
        'TOTAL CONSOLIDADO:',
        'S/ ${montoTotal.toStringAsFixed(2)}',
        width,
      ),
    );
    buffer.writeln(divider(width, '='));

    if (observaciones != null && observaciones.isNotEmpty) {
      buffer.writeln('NOTAS: $observaciones');
      buffer.writeln(divider(width, '-'));
    }

    buffer.writeln(center('Comprobante diario de consolidacion', width));
    buffer.writeln(center('emitido conforme a normativa de SUNAT.', width));
    buffer.writeln(center('Valido para sustento fiscal en Nuevo RUS.', width));
    buffer.writeln(divider(width, '='));

    return buffer.toString();
  }

  /// Genera los bytes ESC/POS para la Boleta Consolidada Diaria
  static List<int> generateBoletaConsolidadaEscPosBytes({
    required String serieCorrelativo,
    required DateTime fechaEmision,
    required double montoTotal,
    required int cantidadOperaciones,
    String tipoEmision = 'TALONARIO_FISICO',
    String? observaciones,
    String? cajero,
    DateTime? fechaRegistro,
    String nombreComercio = 'CajaYa POS',
    String? rucDni,
    String? direccion = 'Av. Principal 123 - Lima',
    String? telefono = 'Tel: 987 654 321',
    String? lemaComercial,
    ConfiguracionTicket? configTicket,
  }) {
    final cfg = configTicket ?? ConfiguracionTicketService.actual;
    final text = generateBoletaConsolidadaText(
      serieCorrelativo: serieCorrelativo,
      fechaEmision: fechaEmision,
      montoTotal: montoTotal,
      cantidadOperaciones: cantidadOperaciones,
      tipoEmision: tipoEmision,
      observaciones: observaciones,
      cajero: cajero,
      fechaRegistro: fechaRegistro,
      width: cfg.anchoPapel,
      nombreComercio: nombreComercio,
      rucDni: rucDni,
      direccion: direccion,
      telefono: telefono,
      lemaComercial: lemaComercial,
    );

    final List<int> bytes = [];

    // 1. Apertura de gaveta de dinero si está configurado
    if (cfg.abrirGaveta) {
      bytes.addAll(openDrawerBytes);
    }

    // 2. Inicializar impresora (ESC @)
    bytes.addAll([0x1B, 0x40]);

    // 3. Contenido en alineación izquierda
    bytes.addAll([0x1B, 0x61, 0x00]);
    bytes.addAll(utf8.encode(text));

    // 4. Avance de 4 líneas de papel (ESC d 4)
    bytes.addAll([0x1B, 0x64, 0x04]);

    // 5. Corte de papel parcial / total
    bytes.addAll(cutPaperBytes);
    return bytes;
  }

  /// Imprime directamente el comprobante de respaldo de Boleta Consolidada Diaria
  static Future<PrintResult> imprimirBoletaConsolidada({
    required String serieCorrelativo,
    required DateTime fechaEmision,
    required double montoTotal,
    required int cantidadOperaciones,
    String tipoEmision = 'TALONARIO_FISICO',
    String? observaciones,
    String? cajero,
    DateTime? fechaRegistro,
    String nombreComercio = 'CajaYa POS',
    String? rucDni,
    String? direccion,
    String? telefono,
    String? lemaComercial,
    ConfiguracionTicket? configTicket,
  }) async {
    final cfg = configTicket ?? ConfiguracionTicketService.actual;
    final plainText = generateBoletaConsolidadaText(
      serieCorrelativo: serieCorrelativo,
      fechaEmision: fechaEmision,
      montoTotal: montoTotal,
      cantidadOperaciones: cantidadOperaciones,
      tipoEmision: tipoEmision,
      observaciones: observaciones,
      cajero: cajero,
      fechaRegistro: fechaRegistro,
      width: cfg.anchoPapel,
      nombreComercio: nombreComercio,
      rucDni: rucDni,
      direccion: direccion,
      telefono: telefono,
      lemaComercial: lemaComercial,
    );

    final escPosBytes = generateBoletaConsolidadaEscPosBytes(
      serieCorrelativo: serieCorrelativo,
      fechaEmision: fechaEmision,
      montoTotal: montoTotal,
      cantidadOperaciones: cantidadOperaciones,
      tipoEmision: tipoEmision,
      observaciones: observaciones,
      cajero: cajero,
      fechaRegistro: fechaRegistro,
      configTicket: cfg,
      nombreComercio: nombreComercio,
      rucDni: rucDni,
      direccion: direccion,
      telefono: telefono,
      lemaComercial: lemaComercial,
    );

    return imprimirTicketDirecto(
      escPosBytes: escPosBytes,
      receiptText: plainText,
      config: cfg,
    );
  }

  /// Wrapper de conveniencia para imprimir comprobantes y volantes
  static Future<PrintResult> printReceipt(
    BuildContext context, {
    required List<int> escPosBytes,
    required String plainText,
    ConfiguracionTicket? configTicket,
  }) => imprimirTicketDirecto(
    escPosBytes: escPosBytes,
    receiptText: plainText,
    config: configTicket,
  );

  /// Despacha la impresión directa al hardware (vía RawBT en móvil/web, servidor local HTTP o fallback)
  static Future<PrintResult> imprimirTicketDirecto({
    required List<int> escPosBytes,
    required String receiptText,
    ConfiguracionTicket? config,
  }) async {
    final cfg = config ?? ConfiguracionTicketService.actual;

    // Modo 0: Bluetooth Nativo Android directo vía RFCOMM / SPP (sin depender de RawBT)
    if (cfg.modoConexion == 'bluetooth_nativo') {
      if (!NativeBluetoothPrinterService.isSupportedPlatform) {
        return const PrintResult(
          exito: false,
          mensaje: 'Bluetooth Nativo Directo solo funciona en la app Android. En navegador usa "Impresión Navegador" o "Servidor Local".',
        );
      }
      final address = cfg.bluetoothDeviceAddress.trim();
      if (address.isEmpty) {
        return const PrintResult(
          exito: false,
          mensaje: 'Selecciona primero tu ticketera Bluetooth vinculada en Configuración > Ticketera.',
        );
      }

      try {
        await NativeBluetoothPrinterService.imprimirBytes(address, escPosBytes);
        final label = cfg.bluetoothDeviceName.trim().isNotEmpty
            ? '${cfg.bluetoothDeviceName.trim()} ($address)'
            : address;
        return PrintResult(
          exito: true,
          mensaje: 'Ticket enviado directamente por Bluetooth a $label.',
        );
      } on PlatformException catch (e) {
        return PrintResult(
          exito: false,
          mensaje: e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : 'No se pudo imprimir por Bluetooth (${e.code}).',
        );
      } catch (e) {
        return PrintResult(
          exito: false,
          mensaje: 'Error inesperado al imprimir vía Bluetooth: $e',
        );
      }
    }

    // Modo 1: RawBT (Bluetooth SPP/BLE, USB y Network)
    if (cfg.modoConexion == 'rawbt') {
      // El esquema de URL `rawbt:` solo existe en Android con la app RawBT instalada.
      // En navegadores Web o Desktop Windows/macOS/Linux abrirlo genera un enlace roto.
      final bool supportsRawBtScheme =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

      if (supportsRawBtScheme) {
        try {
          final b64 = base64Encode(escPosBytes);
          final rawbtUri = Uri.parse(
            'rawbt:data:application/octet-stream;base64,$b64',
          );

          final launched = await launchUrl(
            rawbtUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) {
            return const PrintResult(
              exito: true,
              mensaje: 'Ticket enviado a la impresora térmica vía RawBT.',
            );
          }
        } catch (_) {}
      }

      // Intentar fallback al servidor local / puente ESC/POS (ej. http://127.0.0.1:40213/)
      try {
        final response = await http
            .post(
              Uri.parse(cfg.servidorLocalUrl),
              body: escPosBytes,
              headers: {'Content-Type': 'application/octet-stream'},
            )
            .timeout(const Duration(milliseconds: 1500));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return const PrintResult(
            exito: true,
            mensaje: 'Comando enviado directamente vía puente local ESC/POS.',
          );
        }
      } catch (_) {}

      // En Web, si se trata de imprimir un comprobante con texto, abrir impresión del navegador
      if (kIsWeb && receiptText.isNotEmpty) {
        try {
          final html = generatePrintableHtml(
            receiptText,
            widthMm: cfg.anchoPapel == width80mm ? 80 : 58,
          );
          final uri = Uri.dataFromString(
            html,
            mimeType: 'text/html',
            encoding: utf8,
          );
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
          );
          if (launched) {
            return const PrintResult(
              exito: true,
              mensaje:
                  'Comprobante enviado al diálogo de impresión del navegador.',
            );
          }
        } catch (_) {}
      }

      if (!supportsRawBtScheme) {
        return PrintResult(
          exito: false,
          mensaje: receiptText.isEmpty
              ? 'No se detectó un puente local de gaveta (${cfg.servidorLocalUrl}). En navegador requiere Servidor Local ESC/POS o usar la app Windows/Android.'
              : 'No se detectó el puente local de impresión (${cfg.servidorLocalUrl}). Activa "Impresión Navegador" o "Servidor Local" en Ticket.',
        );
      }

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
            mensaje:
                'Comando enviado con éxito al servidor local de impresión.',
          );
        } else {
          return PrintResult(
            exito: false,
            mensaje:
                'El servidor local de impresión respondió con código ${response.statusCode}.',
          );
        }
      } catch (e) {
        return PrintResult(
          exito: false,
          mensaje:
              'No se pudo conectar al servidor de impresión en ${cfg.servidorLocalUrl}. Revisa que esté activo.',
        );
      }
    }

    // Modo 3: Navegador Web / Impresión Térmica Directa
    if (cfg.modoConexion == 'navegador' && receiptText.isNotEmpty) {
      try {
        final html = generatePrintableHtml(
          receiptText,
          widthMm: cfg.anchoPapel == width80mm ? 80 : 58,
        );
        final uri = Uri.dataFromString(
          html,
          mimeType: 'text/html',
          encoding: utf8,
        );
        final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (launched) {
          return const PrintResult(
            exito: true,
            mensaje:
                'Comprobante enviado al diálogo de impresión del navegador.',
          );
        }
      } catch (_) {}
    }

    // Fallback estándar
    return const PrintResult(
      exito: true,
      mensaje: 'Ticket generado para vista o impresión desde el navegador.',
    );
  }

  /// Genera una página HTML auto-imprimible con estilos CSS térmicos optimizados
  /// (@page margin: 0, ancho 58mm/80mm continuo, fuente monoespaciada)
  /// para impresoras térmicas conectadas por USB a computadoras con Windows/Mac/Linux.
  static String generatePrintableHtml(String receiptText, {int widthMm = 58}) {
    final cleanText = sanitize(receiptText);
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Comprobante de Venta - CajaYa POS</title>
  <style>
    @page {
      margin: 0;
      size: ${widthMm}mm auto;
    }
    body {
      margin: 0;
      padding: 12px 6px;
      background: #f8fafc;
      font-family: 'Courier New', Courier, monospace;
      color: #0f172a;
      display: flex;
      justify-content: center;
    }
    .ticket-paper {
      width: ${widthMm}mm;
      max-width: ${widthMm}mm;
      background: #ffffff;
      padding: 10px 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.08);
      border-radius: 4px;
      font-size: ${widthMm == 80 ? '12px' : '11px'};
      line-height: 1.28;
      white-space: pre-wrap;
      word-break: break-all;
    }
    @media print {
      body { background: transparent; padding: 0; display: block; }
      .ticket-paper { box-shadow: none; border-radius: 0; padding: 0; width: 100%; max-width: 100%; }
    }
  </style>
</head>
<body>
  <div class="ticket-paper"><pre style="margin:0; font-family:inherit; white-space:pre-wrap;">$cleanText</pre></div>
  <script>
    window.onload = function() {
      setTimeout(function() { window.print(); }, 200);
    };
  </script>
</body>
</html>''';
  }

  /// Abre manualmente la gaveta de dinero (cajón monedero) conectada a la ticketera vía RJ11
  /// enviando únicamente el pulso ESC/POS sin emitir papel ni realizar una venta.
  static Future<PrintResult> abrirGavetaDinero({
    ConfiguracionTicket? config,
  }) async {
    final cfg = config ?? ConfiguracionTicketService.actual;

    if (cfg.modoConexion == 'navegador') {
      return const PrintResult(
        exito: false,
        mensaje: 'El modo Navegador no envía pulsos RJ11 a la gaveta. Configura "Servidor Local" en Ticket / Impresora o usa la app Windows/Android.',
      );
    }

    final List<int> pulseBytes = List.from(openDrawerBytes);

    return imprimirTicketDirecto(
      escPosBytes: pulseBytes,
      receiptText: '',
      config: cfg,
    );
  }
}

/// Modelo de ítem para impresión de tickets
class TicketItem {
  final String nombre;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;
  final String? variante;
  final String? notas;

  TicketItem({
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    this.variante,
    this.notas,
  });
}
