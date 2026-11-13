/// Parser especializado para códigos de barras emitidos por balanzas electrónicas de mostrador
/// (Torrey, Systel, Digi, Toledo, Bizerba, CAS) que operan bajo el estándar EAN-13
/// con prefijos in-store '20' o '21'.
class BalanzaBarcodeResult {
  final String rawCode;
  final String codigoBase;
  final double pesoKg;
  final double? precioTotal;
  final bool esPorPeso;

  const BalanzaBarcodeResult({
    required this.rawCode,
    required this.codigoBase,
    required this.pesoKg,
    this.precioTotal,
    this.esPorPeso = true,
  });

  String get sku5 => rawCode.length >= 7 ? rawCode.substring(2, 7) : '';
  String get sku4 => rawCode.length >= 6 ? rawCode.substring(2, 6) : '';

  @override
  String toString() =>
      'BalanzaBarcodeResult(codigoBase: $codigoBase, peso: ${pesoKg.toStringAsFixed(3)} kg, esPorPeso: $esPorPeso)';
}

class BalanzaBarcodeHelper {
  /// Analiza un código escaneado. Retorna [BalanzaBarcodeResult] si es un ticket de balanza válido.
  static BalanzaBarcodeResult? parse(String rawCode) {
    final clean = rawCode.trim();
    if (clean.length != 13) return null;
    if (!clean.startsWith('20') && !clean.startsWith('21')) return null;

    // Prefijo 2 dígitos ('20' o '21')
    // Formato estándar EAN-13 Balanza:
    // [2 dígitos Prefijo][5 dígitos Código Producto][5 dígitos Peso en Gramos][1 dígito Checksum]
    // Ejemplo: 20 00125 00350 4 -> Producto 00125 (o 125), Peso 350g = 0.350 kg
    final cod5 = clean.substring(2, 7);
    final valGramos5 = int.tryParse(clean.substring(7, 12)) ?? 0;
    final pesoKg = (valGramos5 / 1000.0);

    final codigoSinCeros = cod5.replaceFirst(RegExp(r'^0+'), '');
    final codigoFinal = codigoSinCeros.isEmpty ? cod5 : codigoSinCeros;

    return BalanzaBarcodeResult(
      rawCode: clean,
      codigoBase: codigoFinal,
      pesoKg: pesoKg > 0 ? pesoKg : 1.0,
      esPorPeso: true,
    );
  }

  /// Verifica si un código de barras corresponde a una etiqueta generada por balanza
  static bool esCodigoBalanza(String rawCode) {
    final clean = rawCode.trim();
    return clean.length == 13 &&
        (clean.startsWith('20') || clean.startsWith('21'));
  }
}
