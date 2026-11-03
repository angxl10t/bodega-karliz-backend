import 'catalogo_imagenes_service.dart';

/// Modelo ligero para representar información de una marca en el inventario de la bodega
class MarcaInfo {
  final String nombre;
  final int cantidadProductos;

  const MarcaInfo({required this.nombre, required this.cantidadProductos});

  factory MarcaInfo.fromJson(Map<String, dynamic> json) {
    return MarcaInfo(
      nombre: json['marca']?.toString() ?? '',
      cantidadProductos: (json['cantidad'] is num)
          ? (json['cantidad'] as num).toInt()
          : 1,
    );
  }
}

/// Servicio Inteligente de Detección y Normalización de Marcas para Bodegas Peruanas
class MarcaDetectorService {
  MarcaDetectorService._();

  static final List<_BrandRule> _rules = [
    // Bebidas y Gaseosas
    _BrandRule(
      'Inca Kola',
      RegExp(r'\b(inka|inca)\s*[- ]?kola\b', caseSensitive: false),
    ),
    _BrandRule(
      'Coca-Cola',
      RegExp(r'\bcoca\s*[- ]?cola\b', caseSensitive: false),
    ),
    _BrandRule('Pepsi', RegExp(r'\bpepsi(\s*black)?\b', caseSensitive: false)),
    _BrandRule(
      '7Up',
      RegExp(r'\b7\s*[- ]?up\b|\bseven\s*[- ]?up\b', caseSensitive: false),
    ),
    _BrandRule('Concordia', RegExp(r'\bconcordia\b', caseSensitive: false)),
    _BrandRule(
      'Kola Real',
      RegExp(r'\bkola\s*[- ]?real\b|\bkr\b', caseSensitive: false),
    ),
    _BrandRule('Fanta', RegExp(r'\bfanta\b', caseSensitive: false)),
    _BrandRule('Sprite', RegExp(r'\bsprite\b', caseSensitive: false)),
    _BrandRule(
      'San Mateo',
      RegExp(r'\bsan\s*[- ]?mateo\b', caseSensitive: false),
    ),
    _BrandRule(
      'San Luis',
      RegExp(r'\bsan\s*[- ]?luis\b', caseSensitive: false),
    ),
    _BrandRule(
      'Cielo',
      RegExp(r'\bagua\s*cielo\b|\bcielo\b', caseSensitive: false),
    ),
    _BrandRule('Sporade', RegExp(r'\bsporade\b', caseSensitive: false)),
    _BrandRule('Gatorade', RegExp(r'\bgatorade\b', caseSensitive: false)),
    _BrandRule('Volt', RegExp(r'\bvolt\b', caseSensitive: false)),
    _BrandRule(
      'Monster',
      RegExp(r'\bmonster(\s*energy)?\b', caseSensitive: false),
    ),
    _BrandRule(
      'Red Bull',
      RegExp(r'\bred\s*[- ]?bull\b', caseSensitive: false),
    ),
    _BrandRule(
      'Frugos',
      RegExp(r'\bfrugos(\s*del\s*valle)?\b', caseSensitive: false),
    ),
    _BrandRule('Pulp', RegExp(r'\bpulp\b', caseSensitive: false)),
    _BrandRule('Tampico', RegExp(r'\btampico\b', caseSensitive: false)),
    _BrandRule('Cifrut', RegExp(r'\bcifrut\b', caseSensitive: false)),

    // Cervezas y Licores
    _BrandRule(
      'Pilsen Callao',
      RegExp(r'\bpilsen(\s*callao)?\b', caseSensitive: false),
    ),
    _BrandRule(
      'Cristal',
      RegExp(r'\b(cerveza\s*)?cristal\b', caseSensitive: false),
    ),
    _BrandRule(
      'Cusqueña',
      RegExp(r'\bcusqueña|cusquena\b', caseSensitive: false),
    ),
    _BrandRule(
      'Corona',
      RegExp(r'\b(cerveza\s*)?corona\b', caseSensitive: false),
    ),
    _BrandRule(
      'Stella Artois',
      RegExp(r'\bstella(\s*artois)?\b', caseSensitive: false),
    ),
    _BrandRule('Cartavio', RegExp(r'\bcartavio\b', caseSensitive: false)),
    _BrandRule(
      'Santiago Queirolo',
      RegExp(r'\b(santiago\s*)?queirolo\b', caseSensitive: false),
    ),
    _BrandRule('Tabernero', RegExp(r'\btabernero\b', caseSensitive: false)),
    _BrandRule(
      'Johnnie Walker',
      RegExp(r'\bjohnnie\s*walker\b', caseSensitive: false),
    ),
    _BrandRule('Four Loko', RegExp(r'\bfour\s*loko\b', caseSensitive: false)),

    // Lácteos y Desayuno
    _BrandRule('Gloria', RegExp(r'\bgloria\b', caseSensitive: false)),
    _BrandRule('Laive', RegExp(r'\blaive\b', caseSensitive: false)),
    _BrandRule(
      'Ideal',
      RegExp(r'\bideal(\s*(cremosita|amanecer))?\b', caseSensitive: false),
    ),
    _BrandRule('Pura Vida', RegExp(r'\bpura\s*vida\b', caseSensitive: false)),
    _BrandRule('Nestlé', RegExp(r'\bnestl[eé]\b', caseSensitive: false)),
    _BrandRule('Milo', RegExp(r'\bmilo\b', caseSensitive: false)),
    _BrandRule('Nescafé', RegExp(r'\bnescaf[eé]\b', caseSensitive: false)),
    _BrandRule('Altomayo', RegExp(r'\baltomayo\b', caseSensitive: false)),
    _BrandRule('Cafetal', RegExp(r'\bcafetal\b', caseSensitive: false)),
    _BrandRule('Kirma', RegExp(r'\bkirma\b', caseSensitive: false)),
    _BrandRule(
      "McColin's",
      RegExp(r"\bmccolins?|mc\s*colins?\b", caseSensitive: false),
    ),
    _BrandRule('Herbi', RegExp(r'\bherbi\b', caseSensitive: false)),
    _BrandRule('Bimbo', RegExp(r'\bbimbo\b', caseSensitive: false)),
    _BrandRule('Quaker', RegExp(r'\bquaker\b', caseSensitive: false)),
    _BrandRule(
      '3 Ositos',
      RegExp(r'\b3\s*ositos|tres\s*ositos\b', caseSensitive: false),
    ),
    _BrandRule('Ángel', RegExp(r'\b[aá]ngel\b', caseSensitive: false)),
    _BrandRule('Winter\'s', RegExp(r"\bwinter'?s?\b", caseSensitive: false)),
    _BrandRule(
      'Blanca Flor',
      RegExp(r'\bblanca\s*flor\b', caseSensitive: false),
    ),

    // Snacks y Piqueos
    _BrandRule("Lay's", RegExp(r"\blay'?s\b", caseSensitive: false)),
    _BrandRule('Doritos', RegExp(r'\bdoritos\b', caseSensitive: false)),
    _BrandRule('Cheetos', RegExp(r'\bcheetos\b', caseSensitive: false)),
    _BrandRule(
      'Cheese Tris',
      RegExp(r'\bcheese\s*tris\b', caseSensitive: false),
    ),
    _BrandRule('Cuates', RegExp(r'\bcuates\b', caseSensitive: false)),
    _BrandRule('Karinto', RegExp(r'\bkarinto\b', caseSensitive: false)),
    _BrandRule(
      'Piqueo Snax',
      RegExp(r'\bpiqueo\s*snax\b', caseSensitive: false),
    ),
    _BrandRule('Tortees', RegExp(r'\btortees\b', caseSensitive: false)),
    _BrandRule('Chizitos', RegExp(r'\bchizitos?\b', caseSensitive: false)),
    _BrandRule(
      'Frito-Lay',
      RegExp(r'\bfrito\s*[- ]?lay\b', caseSensitive: false),
    ),

    // Golosinas y Chocolates
    _BrandRule("D'Onofrio", RegExp(r"\bd'?onofrio\b", caseSensitive: false)),
    _BrandRule('Sublime', RegExp(r'\bsublime\b', caseSensitive: false)),
    _BrandRule('Triángulo', RegExp(r'\btri[aá]ngulo\b', caseSensitive: false)),
    _BrandRule('Princesa', RegExp(r'\bprincesa\b', caseSensitive: false)),
    _BrandRule('Cua Cua', RegExp(r'\bcua\s*[- ]?cua\b', caseSensitive: false)),
    _BrandRule(
      'Doña Pepa',
      RegExp(r'\bdo[ñn]a\s*pepa\b', caseSensitive: false),
    ),
    _BrandRule('Morochas', RegExp(r'\bmorochas\b', caseSensitive: false)),
    _BrandRule('Casino', RegExp(r'\bcasino\b', caseSensitive: false)),
    _BrandRule('Tentación', RegExp(r'\btentaci[oó]n\b', caseSensitive: false)),
    _BrandRule('Rellenitas', RegExp(r'\brellenitas?\b', caseSensitive: false)),
    _BrandRule('Margarita', RegExp(r'\bmargarita\b', caseSensitive: false)),
    _BrandRule('San Jorge', RegExp(r'\bsan\s*jorge\b', caseSensitive: false)),
    _BrandRule('Costa', RegExp(r'\bcosta\b', caseSensitive: false)),
    _BrandRule('Field', RegExp(r'\bfield\b', caseSensitive: false)),

    // Abarrotes y Despensa
    _BrandRule('Costeño', RegExp(r'\bcoste[ñn]o\b', caseSensitive: false)),
    _BrandRule('Paisana', RegExp(r'\bpaisana\b', caseSensitive: false)),
    _BrandRule('Molitalia', RegExp(r'\bmolitalia\b', caseSensitive: false)),
    _BrandRule(
      'Don Vittorio',
      RegExp(r'\bdon\s*vittorio\b', caseSensitive: false),
    ),
    _BrandRule('Lavaggi', RegExp(r'\blavaggi\b', caseSensitive: false)),
    _BrandRule('Nicolini', RegExp(r'\bnicolini\b', caseSensitive: false)),
    _BrandRule('Anita', RegExp(r'\banita\b', caseSensitive: false)),
    _BrandRule('Primor', RegExp(r'\bprimor\b', caseSensitive: false)),
    _BrandRule(
      'Cil',
      RegExp(r'\baceite\s*cil\b|\bcil\b', caseSensitive: false),
    ),
    _BrandRule('Capri', RegExp(r'\bcapri\b', caseSensitive: false)),
    _BrandRule(
      'AlaCena',
      RegExp(r'\bala\s*cena|alacena\b', caseSensitive: false),
    ),
    _BrandRule('Florida', RegExp(r'\bflorida\b', caseSensitive: false)),
    _BrandRule('Campomar', RegExp(r'\bcampomar\b', caseSensitive: false)),
    _BrandRule('Fanny', RegExp(r'\bfanny\b', caseSensitive: false)),
    _BrandRule('Compass', RegExp(r'\bcompass\b', caseSensitive: false)),
    _BrandRule('Ajinomoto', RegExp(r'\bajinomoto\b', caseSensitive: false)),
    _BrandRule(
      'Doña Gusta',
      RegExp(r'\bdo[ñn]a\s*gusta\b', caseSensitive: false),
    ),
    _BrandRule('Sibarita', RegExp(r'\bsibarita\b', caseSensitive: false)),

    // Limpieza y Cuidado
    _BrandRule('Ariel', RegExp(r'\bariel\b', caseSensitive: false)),
    _BrandRule('Ace', RegExp(r'\bace\b', caseSensitive: false)),
    _BrandRule('Bolívar', RegExp(r'\bbol[ií]var\b', caseSensitive: false)),
    _BrandRule('Opal', RegExp(r'\bopal\b', caseSensitive: false)),
    _BrandRule('Clorox', RegExp(r'\bclorox\b', caseSensitive: false)),
    _BrandRule('Sapolio', RegExp(r'\bsapolio\b', caseSensitive: false)),
    _BrandRule('Ayudín', RegExp(r'\bayud[ií]n\b', caseSensitive: false)),
    _BrandRule('Poett', RegExp(r'\bpoett\b', caseSensitive: false)),
    _BrandRule('Elite', RegExp(r'\belite\b', caseSensitive: false)),
    _BrandRule('Paracas', RegExp(r'\bparacas\b', caseSensitive: false)),
    _BrandRule('Suave', RegExp(r'\b(papel\s*)?suave\b', caseSensitive: false)),
    _BrandRule('Noble', RegExp(r'\bnoble\b', caseSensitive: false)),

    // Cuidado Personal
    _BrandRule('Colgate', RegExp(r'\bcolgate\b', caseSensitive: false)),
    _BrandRule('Dento', RegExp(r'\bdento\b', caseSensitive: false)),
    _BrandRule('Kolynos', RegExp(r'\bkolynos\b', caseSensitive: false)),
    _BrandRule(
      'Head & Shoulders',
      RegExp(r'\bhead\s*(&|and)?\s*shoulders|h&s\b', caseSensitive: false),
    ),
    _BrandRule('Pantene', RegExp(r'\bpantene\b', caseSensitive: false)),
    _BrandRule('Sedal', RegExp(r'\bsedal\b', caseSensitive: false)),
    _BrandRule('Dove', RegExp(r'\bdove\b', caseSensitive: false)),
    _BrandRule('Rexona', RegExp(r'\brexona\b', caseSensitive: false)),
    _BrandRule('Nivea', RegExp(r'\bnivea\b', caseSensitive: false)),
    _BrandRule('Gillette', RegExp(r'\bgillette\b', caseSensitive: false)),
    _BrandRule('Huggies', RegExp(r'\bhuggies\b', caseSensitive: false)),
    _BrandRule('Babysec', RegExp(r'\bbabysec\b', caseSensitive: false)),

    // Tabaco y Fósforos
    _BrandRule(
      'Lucky Strike',
      RegExp(r'\blucky(\s*strike)?\b', caseSensitive: false),
    ),
    _BrandRule(
      'Marlboro',
      RegExp(r'\b(marlboro|malboro)\b', caseSensitive: false),
    ),
    _BrandRule('Hamilton', RegExp(r'\bhamilton\b', caseSensitive: false)),
    _BrandRule('Pall Mall', RegExp(r'\bpall\s*mall\b', caseSensitive: false)),
    _BrandRule('Tokai', RegExp(r'\btokai\b', caseSensitive: false)),
    _BrandRule('La Llama', RegExp(r'\bla\s*llama\b', caseSensitive: false)),
  ];

  /// Detecta automáticamente la marca a partir del nombre o código de barras
  static String? detectarMarca({String? nombre, String? codigoBarras}) {
    // 1. Intento por código de barras exacto (EAN13 sin ambigüedades)
    if (codigoBarras != null && codigoBarras.trim().isNotEmpty) {
      final sug = CatalogoImagenesService.buscarSugerencia(
        codigoBarras: codigoBarras,
      );
      if (sug != null && sug.marca.trim().isNotEmpty) {
        return normalizarMarca(sug.marca);
      }
    }

    // 2. Intento por Reglas Semánticas en el Nombre (detección directa de marca)
    if (nombre != null && nombre.trim().isNotEmpty) {
      final clean = nombre.trim();
      for (final rule in _rules) {
        if (rule.pattern.hasMatch(clean)) {
          return rule.canonicalName;
        }
      }

      // 3. Fallback: búsqueda por catálogo de packshots si no hubo coincidencia regex
      final sug = CatalogoImagenesService.buscarSugerencia(nombre: nombre);
      if (sug != null && sug.marca.trim().isNotEmpty) {
        return normalizarMarca(sug.marca);
      }
    }

    return null;
  }

  /// Normaliza el nombre de la marca (ej. "alacena" -> "AlaCena", "pepsi" -> "Pepsi")
  static String normalizarMarca(String marca) {
    final clean = marca.trim();
    if (clean.isEmpty) return clean;

    // Verificar si coincide con alguna regla canónica
    for (final rule in _rules) {
      if (rule.pattern.hasMatch(clean) ||
          rule.canonicalName.toLowerCase() == clean.toLowerCase()) {
        return rule.canonicalName;
      }
    }

    // Fallback: mayúscula inicial por palabra
    return clean
        .split(RegExp(r'\s+'))
        .map((palabra) {
          if (palabra.isEmpty) return '';
          return palabra[0].toUpperCase() +
              (palabra.length > 1 ? palabra.substring(1).toLowerCase() : '');
        })
        .join(' ');
  }

  /// Simplifica un texto para comparación tolerante a variantes:
  /// convierte a minúsculas, remueve acentos/diacríticos y elimina puntuación, guiones y espacios.
  static String simplificar(String? s) {
    if (s == null || s.trim().isEmpty) return '';
    var str = s.toLowerCase();
    const withDiacritics = 'áàäâãéèëêíìïîóòöôõúùüûñ';
    const withoutDiacritics = 'aaaaaeeeeiiiiooooouuuun';
    for (int i = 0; i < withDiacritics.length; i++) {
      str = str.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return str.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Evalúa con tolerancia exhaustiva a variantes (guiones, espacios, acentos, mayúsculas)
  /// si un producto pertenece a la marca objetivo de una promoción o búsqueda.
  static bool coincideMarca(
    String? marcaObjetivo,
    String? marcaProducto,
    String? nombreProducto,
  ) {
    if (marcaObjetivo == null || marcaObjetivo.trim().isEmpty) return false;

    final targetTrim = marcaObjetivo.trim();
    final canonicalTarget = normalizarMarca(targetTrim);
    final simpTarget = simplificar(targetTrim);
    final simpCanonical = simplificar(canonicalTarget);

    // 1. Reglas Regex Canónicas
    _BrandRule? targetRule;
    for (final rule in _rules) {
      if (rule.canonicalName.toLowerCase() == canonicalTarget.toLowerCase() ||
          simplificar(rule.canonicalName) == simpCanonical ||
          rule.pattern.hasMatch(targetTrim)) {
        targetRule = rule;
        break;
      }
    }
    if (targetRule != null) {
      if (marcaProducto != null &&
          marcaProducto.trim().isNotEmpty &&
          targetRule.pattern.hasMatch(marcaProducto)) {
        return true;
      }
      if (nombreProducto != null &&
          nombreProducto.trim().isNotEmpty &&
          targetRule.pattern.hasMatch(nombreProducto)) {
        return true;
      }
    }

    // 2. Coincidencia directa contra marcaProducto
    if (marcaProducto != null && marcaProducto.trim().isNotEmpty) {
      final prodTrim = marcaProducto.trim();
      if (prodTrim.toLowerCase() == targetTrim.toLowerCase()) return true;
      final canonicalProd = normalizarMarca(prodTrim);
      if (canonicalTarget.toLowerCase() == canonicalProd.toLowerCase())
        return true;

      final simpProd = simplificar(prodTrim);
      if (simpTarget == simpProd || simpCanonical == simpProd) return true;
      if (simpProd.contains(simpTarget) ||
          (simpTarget.length >= 4 && simpTarget.contains(simpProd)))
        return true;
    }

    // 3. Coincidencia contra nombreProducto
    if (nombreProducto != null && nombreProducto.trim().isNotEmpty) {
      final detected = detectarMarca(nombre: nombreProducto);
      if (detected != null) {
        if (detected.toLowerCase() == canonicalTarget.toLowerCase())
          return true;
        if (simplificar(detected) == simpCanonical) return true;
      }
      final simpName = simplificar(nombreProducto);
      if (simpTarget.length >= 3 && simpName.contains(simpTarget)) return true;
      if (simpCanonical.length >= 3 && simpName.contains(simpCanonical))
        return true;
    }

    return false;
  }
}

class _BrandRule {
  final String canonicalName;
  final RegExp pattern;

  _BrandRule(this.canonicalName, this.pattern);
}
