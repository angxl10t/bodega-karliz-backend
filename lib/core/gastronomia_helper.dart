/// Helper con reglas de negocio y opciones gastronómicas (Pollerías, Chifas, Fast Food)
/// para selección de presas, guarniciones, términos de cocción y notas de comanda.
class GastronomiaHelper {
  /// Detecta si un producto requiere seleccionar presa (ej. 1/4 Pollo, Mostrito, Broaster)
  static bool esProductoConPresa(String? nombre, [String? categoria]) {
    if (nombre == null || nombre.trim().isEmpty) return false;
    final n = nombre.toLowerCase();
    final c = (categoria ?? '').toLowerCase();

    // 1/4 Pollo o Cuarto
    if (n.contains('1/4') || n.contains('cuarto') || n.contains('1 / 4')) {
      if (n.contains('pollo') ||
          n.contains('brasa') ||
          n.contains('broaster') ||
          c.contains('brasa') ||
          c.contains('pollo')) {
        return true;
      }
    }

    // Mostrito
    if (n.contains('mostrito')) return true;

    // 1/2 Pollo o Medio: En pollerías NO existe medio pollo de 2 pechos o 2 piernas.
    // Solo sale la forma clásica (Pecho y Pierna), pero se permite personalizar ensalada y papas.
    if (n.contains('1/2') || n.contains('medio') || n.contains('1 / 2')) {
      if (n.contains('pollo') || n.contains('brasa') || c.contains('brasa')) {
        return true;
      }
    }

    // Presas sueltas o Broaster individual (se elige Pecho o Pierna)
    if ((n.contains('presa') || n.contains('broaster')) &&
        (n.contains('pollo') ||
            n.contains('brasa') ||
            c.contains('brasa') ||
            c.contains('pollo'))) {
      return true;
    }

    return false;
  }

  /// Indica si el producto permite elegir entre presas alternativas (ej. 1/4 Pollo: Pecho vs Pierna).
  /// En 1/2 Pollo y Pollo Entero retorna false porque solo se despachan en su forma clásica.
  static bool tienePresaSeleccionable(String? nombre) {
    if (nombre == null) return true;
    final n = nombre.toLowerCase();
    if (n.contains('1/2') ||
        n.contains('medio') ||
        n.contains('1 / 2') ||
        n.contains('entero') ||
        n.contains('completo')) {
      return false;
    }
    return opcionesPresa(nombre).length > 1;
  }

  /// Retorna las opciones de presa según el tipo de plato
  static List<String> opcionesPresa(String? nombre) {
    if (nombre == null) {
      return const ['Pecho (con ala)', 'Pierna (con encuentro)'];
    }
    final n = nombre.toLowerCase();

    // Medio Pollo: En la gastronomía peruana NO existe 2 pechos o 2 piernas.
    // Solo sale la forma clásica: Pecho y Pierna.
    if (n.contains('1/2') || n.contains('medio') || n.contains('1 / 2')) {
      return const ['Pecho y Pierna (Clásico)'];
    }

    // Pollo Entero: Siempre incluye 2 pechos y 2 piernas completas
    if (n.contains('entero') ||
        (n.contains('1 pollo') && !n.contains('1/4') && !n.contains('1/2'))) {
      return const ['Entero Clásico (2 Pechos + 2 Piernas)'];
    }

    // Por defecto para 1/4 Pollo, Mostrito, Broaster:
    return const ['Pecho (con ala)', 'Pierna (con encuentro)'];
  }

  /// Opciones de ensalada para acompañar el pollo a la brasa
  static List<String> opcionesEnsalada() {
    return const ['Ensalada Fresca', 'Ensalada Cocida', 'Sin ensalada'];
  }

  /// Opciones rápidas de guarnición / término de papas
  static List<String> opcionesPapas() {
    return const ['Papas Clásicas', 'Papas Bien Doradas', 'Papas Aparte'];
  }

  /// Opciones de cremas y salsas
  static List<String> opcionesCremas() {
    return const [
      'Todas las cremas',
      'Ají pollero extra',
      'Sin ají',
      'Cremas aparte',
    ];
  }

  /// Formatea el nombre del producto agregando la presa y notas si existen
  static String formatearNombreConVariante(
    String nombre,
    String? variante, [
    String? notas,
  ]) {
    final buffer = StringBuffer(nombre);
    if (variante != null && variante.trim().isNotEmpty) {
      buffer.write(' - $variante');
    }
    if (notas != null && notas.trim().isNotEmpty) {
      buffer.write(' ($notas)');
    }
    return buffer.toString();
  }
}
