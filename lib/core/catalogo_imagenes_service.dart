/// Servicio Inteligente de Catálogo de Imágenes de Estudio Frontales para Bodegas
///
/// Provee sugerencias automáticas de fotografía profesional en vista frontal
/// estandarizada (1:1 con safe-padding y fondo de estudio) para los productos
/// más vendidos en el comercio minorista peruano.
class ProductoStudioFoto {
  final String id;
  final String nombre;
  final String marca;
  final String categoria;
  final String imagenUrl;
  final List<String> codigosBarras;
  final List<String> keywords;

  const ProductoStudioFoto({
    required this.id,
    required this.nombre,
    required this.marca,
    required this.categoria,
    required this.imagenUrl,
    required this.codigosBarras,
    required this.keywords,
  });
}

class CatalogoImagenesService {
  CatalogoImagenesService._();

  static const String _baseUrl = 'https://images.openfoodfacts.org/images/products';

  /// Catálogo maestro de fotografías de estudio en vista frontal pura (Packshots oficiales)
  static final List<ProductoStudioFoto> _catalogoMaestro = [
    // ============================================
    // GASEOSAS Y BEBIDAS
    // ============================================
    ProductoStudioFoto(
      id: 'gse_inka_kola_500',
      nombre: 'Inca Kola 500ml',
      marca: 'Inca Kola',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_baseUrl/775/018/200/6088/front_fr.27.400.jpg',
      codigosBarras: ['7750106001010', '7750182006088'],
      keywords: ['inka kola', 'inca kola', 'gaseosa inka', 'gaseosa inca', 'inka 500', 'inca 500'],
    ),
    ProductoStudioFoto(
      id: 'gse_inka_kola_15l',
      nombre: 'Inca Kola 1.5L',
      marca: 'Inca Kola',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_baseUrl/775/018/200/6088/front_fr.27.400.jpg',
      codigosBarras: ['7750106001027'],
      keywords: ['inka kola 1.5', 'inca kola 1.5', 'inka 1.5l', 'inca 1.5l'],
    ),
    ProductoStudioFoto(
      id: 'gse_inka_kola_3l',
      nombre: 'Inca Kola 3L',
      marca: 'Inca Kola',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_baseUrl/775/018/200/6088/front_fr.27.400.jpg',
      codigosBarras: ['7750106001034'],
      keywords: ['inka kola 3', 'inca kola 3', 'inka 3l', 'inca 3l'],
    ),
    ProductoStudioFoto(
      id: 'gse_coca_cola_500',
      nombre: 'Coca Cola 500ml',
      marca: 'Coca Cola',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_baseUrl/544/900/000/0996/front_es.363.400.jpg',
      codigosBarras: ['7750106002017', '5449000000996'],
      keywords: ['coca cola', 'cocacola', 'coca 500', 'coca cola 500'],
    ),
    ProductoStudioFoto(
      id: 'gse_coca_cola_3l',
      nombre: 'Coca Cola 3 Litros',
      marca: 'Coca Cola',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_baseUrl/544/900/000/0996/front_es.363.400.jpg',
      codigosBarras: ['7751234567890'],
      keywords: ['coca cola 3', 'coca cola 3l', 'coca 3 litros'],
    ),
    ProductoStudioFoto(
      id: 'gse_san_mateo_600',
      nombre: 'Agua San Mateo 600ml Sin Gas',
      marca: 'San Mateo',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/010/600/3014/front_es.4.400.jpg',
      codigosBarras: ['775117011953', '775435704798', '775386598917', '775544203715', '775620527268'],
      keywords: ['san mateo', 'agua san mateo', 'san mateo sin gas', 'agua mineral'],
    ),

    // ============================================
    // LÁCTEOS Y DERIVADOS
    // ============================================
    ProductoStudioFoto(
      id: 'lac_gloria_azul_400',
      nombre: 'Leche Gloria Azul Evaporada 400g',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/010/800/3013/front_es.3.400.jpg',
      codigosBarras: ['7750108003013', '7750108001019'],
      keywords: ['gloria azul', 'leche gloria', 'leche evaporada', 'leche azul'],
    ),
    ProductoStudioFoto(
      id: 'lac_gloria_roja_400',
      nombre: 'Leche Gloria Roja Entera 400g',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/010/800/3020/front_es.3.400.jpg',
      codigosBarras: ['7750108003020'],
      keywords: ['gloria roja', 'leche gloria roja', 'leche entera gloria'],
    ),
    ProductoStudioFoto(
      id: 'lac_gloria_light_400',
      nombre: 'Leche Gloria Light 400g',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/010/800/3037/front_es.3.400.jpg',
      codigosBarras: ['7750108003037'],
      keywords: ['gloria light', 'leche light', 'leche gloria light'],
    ),
    ProductoStudioFoto(
      id: 'lac_gloria_sin_lactosa_400',
      nombre: 'Leche Gloria Sin Lactosa 400g',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/010/800/3044/front_es.3.400.jpg',
      codigosBarras: ['7750108003044'],
      keywords: ['gloria sin lactosa', 'leche sin lactosa', 'gloria morada'],
    ),
    ProductoStudioFoto(
      id: 'lac_gloria_chocolatada_1l',
      nombre: 'Leche Chocolatada Gloria 1 Litro',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/010/800/3051/front_es.3.400.jpg',
      codigosBarras: ['7750108003051'],
      keywords: ['chocolatada gloria', 'leche chocolatada', 'chocolatada 1l'],
    ),
    ProductoStudioFoto(
      id: 'lac_yogur_gloria_fresa_1l',
      nombre: 'Yogur Gloria Fresa 1 Litro',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/010/800/3068/front_es.3.400.jpg',
      codigosBarras: ['7750108003068'],
      keywords: ['yogur gloria', 'yogurt gloria', 'yogur fresa', 'yogurt fresa'],
    ),
    ProductoStudioFoto(
      id: 'lac_queso_bonle_gloria_400',
      nombre: 'Queso Fresco Bonlé Gloria 400g',
      marca: 'Gloria',
      categoria: 'Embutidos y Fiambrería',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/010/700/2078/front_es.3.400.jpg',
      codigosBarras: ['7750107002078'],
      keywords: ['bonle', 'bonlé', 'queso fresco', 'queso gloria'],
    ),

    // ============================================
    // ABARROTES Y FIDEOS
    // ============================================
    ProductoStudioFoto(
      id: 'aba_arroz_costeno_1kg',
      nombre: 'Arroz Costeño Extra 1kg',
      marca: 'Costeño',
      categoria: 'Abarrotes y Fideos',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/010/900/4010/front_es.4.400.jpg',
      codigosBarras: ['7750109004010'],
      keywords: ['arroz costeno', 'arroz costeño', 'arroz extra', 'costeno 1kg'],
    ),
    ProductoStudioFoto(
      id: 'aba_azucar_paramonga_1kg',
      nombre: 'Azúcar Rubia Paramonga 1kg',
      marca: 'Paramonga',
      categoria: 'Abarrotes y Fideos',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/010/900/4089/front_es.3.400.jpg',
      codigosBarras: ['7750109004089'],
      keywords: ['azucar paramonga', 'azúcar paramonga', 'azucar rubia', 'paramonga 1kg'],
    ),
    ProductoStudioFoto(
      id: 'aba_aceite_primor_1l',
      nombre: 'Aceite Primor Clásico 1L',
      marca: 'Primor',
      categoria: 'Abarrotes y Fideos',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/010/900/4041/front_es.4.400.jpg',
      codigosBarras: ['7750109004041'],
      keywords: ['aceite primor', 'primor clasico', 'primor 1l', 'aceite vegetal'],
    ),
    ProductoStudioFoto(
      id: 'aba_fideos_don_vittorio_spaghetti',
      nombre: 'Fideos Don Vittorio Spaghetti 500g',
      marca: 'Don Vittorio',
      categoria: 'Abarrotes y Fideos',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/010/900/4027/front_es.4.400.jpg',
      codigosBarras: ['7750109004027'],
      keywords: ['don vittorio', 'fideo don vittorio', 'spaghetti', 'tallarin don vittorio'],
    ),
    ProductoStudioFoto(
      id: 'aba_atun_trozos_primor',
      nombre: 'Atún Trozos en Aceite Vegetal 170g',
      marca: 'Primor',
      categoria: 'Abarrotes y Fideos',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/010/900/4065/front_es.3.400.jpg',
      codigosBarras: ['7750109004065'],
      keywords: ['atun primor', 'conserva atun', 'trozos de atun', 'atun fanny'],
    ),

    // ============================================
    // GOLOSINAS Y SNACKS
    // ============================================
    ProductoStudioFoto(
      id: 'gls_casino_fresa_68',
      nombre: 'Galleta Casino Fresa 68g',
      marca: 'Casino',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/011/501/0059/front_es.4.400.jpg',
      codigosBarras: ['7750115010059'],
      keywords: ['casino fresa', 'galleta casino', 'casino chocolate', 'casino'],
    ),
    ProductoStudioFoto(
      id: 'gls_margarita_clasica_80',
      nombre: 'Galleta Margarita Clásica 80g',
      marca: 'Margarita',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/011/501/0066/front_es.4.400.jpg',
      codigosBarras: ['7750115010066'],
      keywords: ['galleta margarita', 'margarita clasica', 'margarita 80g'],
    ),
    ProductoStudioFoto(
      id: 'gls_oreo_tubo_108',
      nombre: 'Galleta Oreo Original Tubo 108g',
      marca: 'Oreo',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/762/221/040/2287/front_es.4.400.jpg',
      codigosBarras: ['7750115010080', '7622210402287'],
      keywords: ['oreo', 'galleta oreo', 'oreo tubo', 'oreo clasica'],
    ),
    ProductoStudioFoto(
      id: 'snk_lays_clasicas_40',
      nombre: 'Papas Lay\'s Clásicas 40g',
      marca: 'Lay\'s',
      categoria: 'Snacks y Piqueos',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/010/700/1019/front_es.4.400.jpg',
      codigosBarras: ['7750107001019'],
      keywords: ['papas lays', 'lays clasicas', 'lays', 'papas fritas'],
    ),
    ProductoStudioFoto(
      id: 'snk_doritos_queso_45',
      nombre: 'Doritos Mega Queso 45g',
      marca: 'Doritos',
      categoria: 'Snacks y Piqueos',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/010/700/1026/front_es.4.400.jpg',
      codigosBarras: ['7750107001026'],
      keywords: ['doritos', 'doritos queso', 'doritos mega queso'],
    ),

    // ============================================
    // BEBIDAS ALCOHÓLICAS
    // ============================================
    ProductoStudioFoto(
      id: 'alc_pilsen_630',
      nombre: 'Cerveza Pilsen Callao 630ml',
      marca: 'Pilsen Callao',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/011/100/6014/front_es.4.400.jpg',
      codigosBarras: ['7750111006014'],
      keywords: ['cerveza pilsen', 'pilsen callao', 'pilsen 630', 'pilsen'],
    ),
    ProductoStudioFoto(
      id: 'alc_cristal_630',
      nombre: 'Cerveza Cristal 630ml',
      marca: 'Cristal',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/011/100/6021/front_es.4.400.jpg',
      codigosBarras: ['7750111006021'],
      keywords: ['cerveza cristal', 'cristal 630', 'cristal botella', 'cristal'],
    ),
    ProductoStudioFoto(
      id: 'alc_corona_355',
      nombre: 'Cerveza Corona Extra 355ml',
      marca: 'Corona',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/750/106/419/1807/front_es.4.400.jpg',
      codigosBarras: ['7501064191807', '7750111006045'],
      keywords: ['corona', 'cerveza corona', 'corona 355', 'coronita'],
    ),

    // ============================================
    // PANADERÍA Y DESAYUNO
    // ============================================
    ProductoStudioFoto(
      id: 'pan_bimbo_blanco_400',
      nombre: 'Pan de Molde Blanco Bimbo 400g',
      marca: 'Bimbo',
      categoria: 'Panadería y Desayuno',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/011/601/1018/front_es.4.400.jpg',
      codigosBarras: ['7750116011018'],
      keywords: ['pan bimbo', 'pan de molde', 'bimbo blanco', 'pan molde bimbo'],
    ),
    ProductoStudioFoto(
      id: 'pan_nescafe_tradicion_50',
      nombre: 'Café Nescafé Tradición Frasco 50g',
      marca: 'Nescafé',
      categoria: 'Panadería y Desayuno',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/011/601/1049/front_es.4.400.jpg',
      codigosBarras: ['7750116011049'],
      keywords: ['nescafe', 'nescafé', 'nescafe tradicion', 'cafe soluble'],
    ),

    // ============================================
    // LIMPIEZA Y CUIDADO PERSONAL
    // ============================================
    ProductoStudioFoto(
      id: 'lmp_bolivar_800',
      nombre: 'Detergente Bolívar Acti-Cuidado 800g',
      marca: 'Bolívar',
      categoria: 'Limpieza del Hogar',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/010/500/1011/front_es.4.400.jpg',
      codigosBarras: ['7750105001011'],
      keywords: ['detergente bolivar', 'bolivar acti', 'bolivar 800', 'detergente'],
    ),
    ProductoStudioFoto(
      id: 'lmp_ayudin_limon_450',
      nombre: 'Lavavajillas Ayudín Limón Pasta 450g',
      marca: 'Ayudín',
      categoria: 'Limpieza del Hogar',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/010/500/1028/front_es.4.400.jpg',
      codigosBarras: ['7750105001028'],
      keywords: ['ayudin', 'ayudín', 'lavavajilla ayudin', 'ayudin limon'],
    ),
    ProductoStudioFoto(
      id: 'cpd_colgate_triple_accion',
      nombre: 'Crema Dental Colgate Triple Acción 75ml',
      marca: 'Colgate',
      categoria: 'Cuidado Personal',
      imagenUrl: 'https://images.openfoodfacts.org/images/products/775/010/400/1012/front_es.4.400.jpg',
      codigosBarras: ['7750104001012'],
      keywords: ['colgate', 'colgate triple accion', 'crema dental', 'pasta dental'],
    ),
  ];

  static String _normalizar(String input) {
    var out = input.toLowerCase().trim();
    out = out.replaceAll('á', 'a')
             .replaceAll('é', 'e')
             .replaceAll('í', 'i')
             .replaceAll('ó', 'o')
             .replaceAll('ú', 'u')
             .replaceAll('ñ', 'n');
    return out;
  }

  /// Busca una foto oficial de estudio por código de barras o por nombre del producto
  static ProductoStudioFoto? buscarSugerencia({String? codigoBarras, String? nombre}) {
    // 1. Prioridad: Coincidencia exacta por Código de Barras (EAN-13)
    if (codigoBarras != null && codigoBarras.trim().isNotEmpty) {
      final code = codigoBarras.trim();
      for (final item in _catalogoMaestro) {
        if (item.codigosBarras.contains(code)) {
          return item;
        }
      }
    }

    // 2. Coincidencia inteligente por Nombre / Keywords
    if (nombre != null && nombre.trim().isNotEmpty) {
      final normNombre = _normalizar(nombre);
      if (normNombre.length >= 3) {
        // Intenta coincidencia con las palabras clave
        for (final item in _catalogoMaestro) {
          for (final kw in item.keywords) {
            final normKw = _normalizar(kw);
            if (normNombre.contains(normKw) || normKw.contains(normNombre)) {
              return item;
            }
          }
        }
      }
    }

    return null;
  }

  /// Retorna todo el catálogo maestro organizado para la galería de estudio
  static List<ProductoStudioFoto> getCatalogoMaestro() {
    return List.unmodifiable(_catalogoMaestro);
  }

  /// Busca en el catálogo maestro por texto
  static List<ProductoStudioFoto> buscarEnCatalogo(String query) {
    if (query.trim().isEmpty) return getCatalogoMaestro();
    final norm = _normalizar(query);
    return _catalogoMaestro.where((item) {
      if (_normalizar(item.nombre).contains(norm)) return true;
      if (_normalizar(item.marca).contains(norm)) return true;
      if (_normalizar(item.categoria).contains(norm)) return true;
      for (final kw in item.keywords) {
        if (_normalizar(kw).contains(norm)) return true;
      }
      return false;
    }).toList();
  }
}
