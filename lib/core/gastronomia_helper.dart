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

  /// Retorna la prioridad culinaria para ordenamiento:
  /// 1: Platos Principales (Brasas, Pollos enteros/medios/cuartos, Mostritos, Combos familiares, Broaster, Chifas, Platos de fondo)
  /// 2: Entradas y Guarniciones (Papas fritas, Ensaladas, Tequeños, Sopas, Yuca, Camote)
  /// 3: Bebidas y Gaseosas (Gaseosas, Chicha, Jugos, Aguas, Cervezas)
  /// 4: Salsas, Cremas y Extras (Ají pollero extra, Mayonesa, Vinagretas, Tártara, Sachets)
  static int prioridadCulinaria(String? nombre, [String? categoria]) {
    final n = (nombre ?? '').toLowerCase();
    final c = (categoria ?? '').toLowerCase();

    // 1. Platos Principales específicos que podrían tener palabras clave engañosas
    if (n.contains('ají de gallina') || n.contains('aji de gallina')) {
      return 1;
    }

    // Combos y banquetes familiares siguen siendo Platos Principales (aunque mencionen gaseosa o papas)
    if (n.contains('combo') ||
        n.contains('banquete') ||
        n.contains('familiar') ||
        n.contains('parrillada') ||
        n.contains('duo') ||
        n.contains('dúo')) {
      return 1;
    }

    // Pollos a la brasa, broaster y mostritos son Platos Principales de máxima prioridad
    if (n.contains('pollo') ||
        n.contains('brasa') ||
        n.contains('broaster') ||
        n.contains('mostrito') ||
        n.contains('1/4') ||
        n.contains('1/2') ||
        n.contains('cuarto') ||
        n.contains('medio pollo') ||
        c.contains('brasa') ||
        c.contains('pollo')) {
      if (n.startsWith('salsa') || n.startsWith('crema')) {
        return 4;
      }
      return 1;
    }

    // Chifas y platos salteados orientales son Platos Principales
    if (n.contains('chaufa') ||
        n.contains('aeropuerto') ||
        n.contains('tallarin') ||
        n.contains('tallarín') ||
        n.contains('chi jau kay') ||
        n.contains('chijaukay') ||
        n.contains('tipakay') ||
        n.contains('kam lu') ||
        n.contains('saltado') ||
        c.contains('chifa') ||
        c.contains('arroz') ||
        c.contains('salteado')) {
      if (n.contains('porcion de arroz') || n.contains('porción de arroz')) {
        return 2;
      }
      return 1;
    }

    // 2. Cremas y Salsas (Priority 4 - complementos y extras al final de la carta)
    if (c.contains('salsa') ||
        c.contains('crema') ||
        c.contains('adicional') ||
        c.contains('extra') ||
        c.contains('condimento')) {
      return 4;
    }
    if (n.contains('crema') ||
        n.contains('salsa') ||
        n.contains('ají pollero') ||
        n.contains('aji pollero') ||
        n.contains('mayonesa') ||
        n.contains('ketchup') ||
        n.contains('kétchup') ||
        n.contains('vinagreta') ||
        n.contains('tártara') ||
        n.contains('tartara') ||
        n.contains('golf') ||
        n.contains('chimichurri') ||
        n.contains('aderezo') ||
        n.contains('sachet')) {
      return 4;
    }

    // 3. Bebidas y Gaseosas (Priority 3 - bebidas van tras la comida)
    if (c.contains('bebida') ||
        c.contains('gaseosa') ||
        c.contains('refresco') ||
        c.contains('licor') ||
        c.contains('cerveza') ||
        c.contains('agua') ||
        c.contains('jugo')) {
      return 3;
    }
    if (n.contains('gaseosa') ||
        n.contains('kola') ||
        n.contains('cola') ||
        n.contains('fanta') ||
        n.contains('sprite') ||
        n.contains('chicha') ||
        n.contains('limonada') ||
        n.contains('maracuy') ||
        n.contains('cerveza') ||
        n.contains('pilsen') ||
        n.contains('cusqueña') ||
        n.contains('cusquena') ||
        n.contains('cristal') ||
        n.contains('agua') ||
        n.contains('jugo') ||
        n.contains('jarra') ||
        n.contains('500ml') ||
        n.contains('1.5l') ||
        n.contains('2.25l') ||
        n.contains('3l') ||
        n.contains('litro')) {
      return 3;
    }

    // 4. Guarniciones, Porciones y Entradas (Priority 2)
    if (c.contains('guarnicion') ||
        c.contains('guarnición') ||
        c.contains('porcion') ||
        c.contains('porción') ||
        c.contains('entrada') ||
        c.contains('ensalada') ||
        c.contains('acompañamiento')) {
      return 2;
    }
    if (n.contains('papas') ||
        n.contains('papa') ||
        n.contains('ensalada') ||
        n.contains('tequeño') ||
        n.contains('tequeno') ||
        n.contains('wantan') ||
        n.contains('wantán') ||
        n.contains('sopa') ||
        n.contains('arroz blanco') ||
        n.contains('yuca') ||
        n.contains('camote')) {
      return 2;
    }

    // Categorías explícitas de platos de fondo
    if (c.contains('fondo') ||
        c.contains('principal') ||
        c.contains('especialidad') ||
        c.contains('carta') ||
        c.contains('parrilla') ||
        c.contains('hamburguesa')) {
      return 1;
    }

    // Por defecto en gastronomía, si no es crema ni bebida ni guarnición, es plato principal
    return 1;
  }

  /// Retorna la prioridad de una categoría para las pestañas de navegación
  static int prioridadCategoria(String? categoria) {
    if (categoria == null) return 1;
    final c = categoria.toLowerCase();
    if (c.contains('brasa') ||
        c.contains('pollo') ||
        c.contains('chifa') ||
        c.contains('arroz') ||
        c.contains('fondo') ||
        c.contains('principal') ||
        c.contains('combo') ||
        c.contains('especialidad') ||
        c.contains('parrilla') ||
        c.contains('hamburguesa')) {
      return 1;
    }
    if (c.contains('guarnicion') ||
        c.contains('guarnición') ||
        c.contains('porcion') ||
        c.contains('porción') ||
        c.contains('entrada') ||
        c.contains('ensalada')) {
      return 2;
    }
    if (c.contains('bebida') ||
        c.contains('gaseosa') ||
        c.contains('refresco') ||
        c.contains('licor') ||
        c.contains('cerveza')) {
      return 3;
    }
    if (c.contains('salsa') ||
        c.contains('crema') ||
        c.contains('adicional') ||
        c.contains('extra')) {
      return 4;
    }
    return 1;
  }

  /// Título de cabecera visual para secciones en la carta online completa
  static String nombreSeccionCulinaria(
    int prioridad, {
    bool esPolleria = true,
    bool esChifa = false,
  }) {
    switch (prioridad) {
      case 1:
        if (esChifa) return '🔥 Platos Fuertes & Especialidades al Wok';
        if (esPolleria) return '🔥 Brasas & Platos Principales';
        return '🔥 Platos Principales de la Casa';
      case 2:
        return '🍟 Guarniciones & Entradas';
      case 3:
        return '🥤 Bebidas & Gaseosas Heladas';
      case 4:
        return '🥣 Salsas & Cremas Caseras';
      default:
        return '🍽️ Platos de la Carta';
    }
  }

  /// Subtítulo sugerido para la sección culinaria
  static String subtituloSeccionCulinaria(int prioridad) {
    switch (prioridad) {
      case 1:
        return 'Los favoritos recién horneados y preparados al fuego vivo';
      case 2:
        return 'El acompañamiento perfecto para disfrutar en mesa o a domicilio';
      case 3:
        return 'Jarras caseras y gaseosas bien heladas para refrescar';
      case 4:
        return 'Ají de pollería artesanal, vinagretas y cremas para acompañar';
      default:
        return 'Selección exclusiva de nuestra cocina';
    }
  }
}
