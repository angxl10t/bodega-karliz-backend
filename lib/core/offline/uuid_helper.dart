import 'dart:math';

/// Generador criptográficamente seguro de Identificadores Únicos Universales (UUID v4)
/// conforme al estándar RFC 4122.
/// Se utiliza como Clave de Idempotencia (`idempotencyKey`) para garantizar que ninguna
/// venta se duplique al reenviarse tras cortes de red o sincronizaciones en lote.
class UuidHelper {
  static final Random _secureRandom = Random.secure();

  /// Genera un UUID v4 (ej: `c7a19e24-9b88-4a12-8e1f-7b0024f9c18d`)
  static String generateV4() {
    final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));

    // Versión 4: bits 12 a 15 fijados en 0100
    bytes[6] = (bytes[6] & 0x0f) | 0x40;

    // Variante RFC 4122: bits 6 y 7 fijados en 10
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Genera un correlativo legible para tickets de venta offline
  /// (ej: `TK-OFF-8392-1729`)
  static String generateLocalTicket(int idBodega) {
    final now = DateTime.now();
    final millis = (now.millisecondsSinceEpoch % 100000).toString().padLeft(5, '0');
    final rand = (_secureRandom.nextInt(900) + 100).toString();
    return 'TK-OFF-$millis-$rand';
  }
}
