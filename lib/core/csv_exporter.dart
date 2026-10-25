import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../features/productos/producto_model.dart';
import '../features/ventas/venta_model.dart';
import '../features/clientes/cliente_model.dart';
import '../features/dashboard/dashboard_bi_model.dart';

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

  /// Genera contenido CSV formateado para libreta de clientes y cuentas fiadas
  static String generarCsvClientes(List<Cliente> clientes) {
    final buffer = StringBuffer();
    buffer.writeln('NombreCompleto,Documento,Telefono,Direccion,LimiteCredito,SaldoDeudor,CreditoDisponible,EstadoDeuda,Notas');

    for (final c in clientes) {
      buffer.write('${escapar(c.nombreCompleto)},');
      buffer.write('${escapar(c.documento ?? "-")},');
      buffer.write('${escapar(c.telefono ?? "-")},');
      buffer.write('${escapar(c.direccion ?? "-")},');
      buffer.write('${c.limiteCredito.toStringAsFixed(2)},');
      buffer.write('${c.saldoDeudor.toStringAsFixed(2)},');
      buffer.write('${c.creditoDisponible.toStringAsFixed(2)},');
      buffer.write('${c.tieneDeuda ? "CON_DEUDA" : "AL_DIA"},');
      buffer.writeln(escapar(c.notas ?? ""));
    }

    return buffer.toString();
  }

  /// Genera contenido CSV formateado para el Reporte Ejecutivo BI de Analítica de Negocio
  static String generarCsvDashboardBi(DashboardBiData data) {
    final buffer = StringBuffer();
    buffer.writeln('=== REPORTE EJECUTIVO BI Y RENTABILIDAD CAJAYA ===');
    buffer.writeln('Periodo Analizado (Dias),${data.diasAnalizados}');
    buffer.writeln('Total Ventas Brutas (PEN),${data.totalVentas.toStringAsFixed(2)}');
    buffer.writeln('Costo Total de Ventas (PEN),${data.totalCostos.toStringAsFixed(2)}');
    buffer.writeln('Margen Bruto de Ganancia (PEN),${data.margenBrutoSoles.toStringAsFixed(2)}');
    buffer.writeln('Margen Bruto Porcentual (%),${data.porcentajeMargenBruto.toStringAsFixed(1)}%');
    buffer.writeln('Ticket Promedio Hoy (PEN),${data.ticketPromedioHoy.toStringAsFixed(2)}');
    buffer.writeln('Ticket Promedio Semanal (PEN),${data.ticketPromedioSemanal.toStringAsFixed(2)}');
    buffer.writeln('Ticket Promedio Periodo (PEN),${data.ticketPromedioPeriodo.toStringAsFixed(2)}');
    buffer.writeln('Cantidad de Ventas en Periodo,${data.cantidadVentasPeriodo}');
    buffer.writeln('Total Capital Inmovilizado en Huesos (PEN),${data.totalCapitalInmovilizado.toStringAsFixed(2)}');
    buffer.writeln('Hora Pico Maxima,${escapar(data.horaPicoMaxima)}');
    buffer.writeln('Hora Valle Minima,${escapar(data.horaValleMinima)}');
    buffer.writeln('Recomendacion Turnos,${escapar(data.recomendacionTurnos)}');
    buffer.writeln();

    buffer.writeln('--- PRODUCTOS ESTRELLA (TOP RENTABILIDAD Y ROTACION) ---');
    buffer.writeln('Ranking,Codigo,Nombre,Categoria,UnidadesVendidas,TotalVentasPEN,CostoTotalPEN,MargenSolesPEN,MargenPorcentaje');
    for (int i = 0; i < data.productosEstrella.length; i++) {
      final p = data.productosEstrella[i];
      buffer.write('${i + 1},');
      buffer.write('${escapar(p.codigo ?? "-")},');
      buffer.write('${escapar(p.nombre)},');
      buffer.write('${escapar(p.categoria)},');
      buffer.write('${p.unidadesVendidas.toStringAsFixed(2)},');
      buffer.write('${p.totalVentas.toStringAsFixed(2)},');
      buffer.write('${p.costoTotal.toStringAsFixed(2)},');
      buffer.write('${p.margenBrutoSoles.toStringAsFixed(2)},');
      buffer.writeln('${p.porcentajeMargen.toStringAsFixed(1)}%');
    }
    buffer.writeln();

    buffer.writeln('--- PRODUCTOS HUESO (SIN VENTAS / CAPITAL INMOVILIZADO) ---');
    buffer.writeln('Ranking,Codigo,Nombre,Categoria,StockActual,PrecioCostoPEN,CapitalInmovilizadoPEN,DiasSinVentas,AccionRecomendada');
    for (int i = 0; i < data.productosHueso.length; i++) {
      final h = data.productosHueso[i];
      buffer.write('${i + 1},');
      buffer.write('${escapar(h.codigo ?? "-")},');
      buffer.write('${escapar(h.nombre)},');
      buffer.write('${escapar(h.categoria)},');
      buffer.write('${h.stockActual.toStringAsFixed(2)},');
      buffer.write('${h.precioCosto.toStringAsFixed(2)},');
      buffer.write('${h.capitalInmovilizado.toStringAsFixed(2)},');
      buffer.write('${h.diasSinVentas},');
      buffer.writeln(escapar(h.accionRecomendada));
    }
    buffer.writeln();

    buffer.writeln('--- DISTRIBUCION HORARIA Y AFLUENCIA (24 HORAS) ---');
    buffer.writeln('Hora,RangoHorario,CantidadTickets,TotalVentasPEN,EsHoraPico');
    for (final hp in data.distribucionHoraria) {
      buffer.write('${hp.hora},');
      buffer.write('${escapar(hp.etiquetaHora)},');
      buffer.write('${hp.cantidadTickets},');
      buffer.write('${hp.totalVentas.toStringAsFixed(2)},');
      buffer.writeln(hp.esPico ? 'SI' : 'NO');
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
