// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:convert';

bool descargarArchivoWeb(String nombreArchivo, String contenidoCsv) {
  try {
    // Incluir BOM UTF-8 (\uFEFF) para que Excel reconozca tildes y caracteres en español
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(contenidoCsv)];
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', nombreArchivo)
      ..click();
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (_) {
    return false;
  }
}
