import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../features/productos/producto_model.dart';
import '../features/ventas/venta_model.dart';

import 'csv_downloader_stub.dart'
    if (dart.library.html) 'csv_downloader_web.dart' as downloader;

class CsvExporter {
  /// Protege contra CSV / Formula Injection y escapa comas y comillas
  static String escapar(String? value) {
    if (value == null || value.isEmpty) return '';
    String clean = value.trim();
    // Formula Injection Prevention (Excel/Google Sheets)
    if (clean.startsWith('=') ||
        clean.startsWith('+') ||
        clean.startsWith('-') ||
        clean.startsWith('@') ||
        clean.startsWith('\t') ||
        clean.startsWith('\r')) {
      clean = "'$clean";
    }
    if (clean.contains(',') || clean.contains('"') || clean.contains('\n') || clean.contains('\r')) {
      clean = '"${clean.replaceAll('"', '""')}"';
    }
    return clean;
  }

  /// Genera contenido CSV formateado para catálogo de productos
  static String generarCsvProductos(List<Producto> productos) {
    final buffer = StringBuffer();
    buffer.writeln('Codigo,CodigoBarras,Nombre,Categoria,Marca,PrecioVenta,StockActual,StockMinimo,Estado');

    for (final p in productos) {
      buffer.write('${escapar(p.codigo)},');
      buffer.write('${escapar(p.codigoBarras)},');
      buffer.write('${escapar(p.nombre)},');
      buffer.write('${escapar(p.nombreCategoria ?? "General")},');
      buffer.write('${escapar(p.marca)},');
      buffer.write('${p.precioVenta.toStringAsFixed(2)},');
      buffer.write('${p.stockActual.toStringAsFixed(3)},');
      buffer.write('${p.stockMinimo.toStringAsFixed(3)},');
      buffer.writeln(p.stockActual > 0 ? 'ACTIVO' : 'AGOTADO');
    }

    return buffer.toString();
  }

  /// Genera contenido CSV formateado para historial de ventas
  static String generarCsvVentas(List<VentaRegistro> ventas) {
    final buffer = StringBuffer();
    buffer.writeln('IDVenta,FechaHora,TipoComprobante,SerieNumero,Cliente,Documento,MetodoPago,Total,EstadoSUNAT,EstadoVenta');

    for (final v in ventas) {
      buffer.write('${v.idVenta},');
      buffer.write('${escapar(v.fechaVenta?.toIso8601String() ?? "")},');
      buffer.write('${escapar(v.tipoComprobante)},');
      buffer.write('${escapar(v.serieCorrelativo ?? "#${v.idVenta}")},');
      buffer.write('${escapar(v.clienteNombre)},');
      buffer.write('${escapar(v.clienteDocumento ?? "-")},');
      buffer.write('${escapar(v.metodoPago)},');
      buffer.write('${v.total.toStringAsFixed(2)},');
      buffer.write('${escapar(v.estadoSunat ?? "NO_APLICA")},');
      buffer.writeln(escapar(v.estado));
    }

    return buffer.toString();
  }

  /// Descarga el CSV en navegador Web o lo copia al portapapeles en dispositivo móvil
  static Future<bool> descargarOCompartirCsv({
    required String nombreArchivo,
    required String contenidoCsv,
  }) async {
    try {
      if (kIsWeb) {
        return downloader.descargarArchivoWeb(nombreArchivo, contenidoCsv);
      } else {
        await Clipboard.setData(ClipboardData(text: contenidoCsv));
        return true;
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: contenidoCsv));
      return false;
    }
  }
}
