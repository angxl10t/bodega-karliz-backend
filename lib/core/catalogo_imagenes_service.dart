/// Servicio Inteligente de Catálogo de Imágenes de Estudio Frontales para Bodegas
///
/// Provee fotografías profesionales de estudio en vista frontal pura (Packshots 1:1)
/// servidas directamente desde la infraestructura local de CajaYa Cloud POS (Same-Origin).
/// 100% libre de CORS, sin bloqueos de CanvasKit y con carga instantánea (<20ms).
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

  static const String _basePath = 'packshots';

  /// Catálogo maestro de fotografías de estudio en vista frontal pura (Packshots oficiales)
  static final List<ProductoStudioFoto> _catalogoMaestro = [
    ProductoStudioFoto(
      id: 'salchicha_huachana',
      nombre: 'Salchicha Huachana Laive 250g',
      marca: 'Laive',
      categoria: 'Embutidos y Fiambrería',
      imagenUrl: '$_basePath/salchicha_huachana.png',
      codigosBarras: ['7750107002030'],
      keywords: ['250g', 'huachana', 'laive', 'salchicha'],
    ),
    ProductoStudioFoto(
      id: 'tocino_braedt',
      nombre: 'Tocino Ahumado en Tiras Braedt 170g',
      marca: 'Braedt',
      categoria: 'Embutidos y Fiambrería',
      imagenUrl: '$_basePath/tocino_braedt.png',
      codigosBarras: ['7750107002047'],
      keywords: ['170g', 'ahumado', 'braedt', 'tiras', 'tocino'],
    ),
    ProductoStudioFoto(
      id: 'chorizo_parrillero',
      nombre: 'Chorizo Parrillero San Fernando pack x4',
      marca: 'San Fernando',
      categoria: 'Embutidos y Fiambrería',
      imagenUrl: '$_basePath/chorizo_parrillero.png',
      codigosBarras: ['7750107002054'],
      keywords: ['chorizo', 'fernando', 'pack', 'parrillero', 'san'],
    ),
    ProductoStudioFoto(
      id: 'queso_edam',
      nombre: 'Queso Edam Laminado Laive 200g',
      marca: 'Laive',
      categoria: 'Embutidos y Fiambrería',
      imagenUrl: '$_basePath/queso_edam.png',
      codigosBarras: ['7750107002061'],
      keywords: ['200g', 'edam', 'laive', 'laminado', 'queso'],
    ),
    ProductoStudioFoto(
      id: 'queso_fresco_bonle',
      nombre: 'Queso Fresco Bonlé Gloria 400g',
      marca: 'Gloria',
      categoria: 'Embutidos y Fiambrería',
      imagenUrl: '$_basePath/queso_fresco_bonle.png',
      codigosBarras: ['7750107002078'],
      keywords: ['400g', 'bonlé', 'fresco', 'gloria', 'queso'],
    ),
    ProductoStudioFoto(
      id: 'jamon_del_pais',
      nombre: 'Jamón del País Braedt 150g',
      marca: 'Braedt',
      categoria: 'Embutidos y Fiambrería',
      imagenUrl: '$_basePath/jamon_del_pais.png',
      codigosBarras: ['7750107002085'],
      keywords: ['150g', 'braedt', 'del', 'jamón', 'país'],
    ),
    ProductoStudioFoto(
      id: 'leche_gloria_azul',
      nombre: 'Leche Gloria Azul Evaporada 400g',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: '$_basePath/leche_gloria_azul.png',
      codigosBarras: ['7750108003013', '7750243000012'],
      keywords: ['400g', 'azul', 'evaporada', 'gloria', 'leche'],
    ),
    ProductoStudioFoto(
      id: 'leche_gloria_roja',
      nombre: 'Leche Gloria Roja Entera 400g',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: '$_basePath/leche_gloria_roja.png',
      codigosBarras: ['7750108003020'],
      keywords: ['400g', 'entera', 'gloria', 'leche', 'roja'],
    ),
    ProductoStudioFoto(
      id: 'leche_gloria_light',
      nombre: 'Leche Gloria Light 400g',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: '$_basePath/leche_gloria_light.png',
      codigosBarras: ['7750108003037'],
      keywords: ['400g', 'gloria', 'leche', 'light'],
    ),
    ProductoStudioFoto(
      id: 'leche_gloria_sin_lactosa',
      nombre: 'Leche Gloria Sin Lactosa 400g',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: '$_basePath/leche_gloria_sin_lactosa.png',
      codigosBarras: ['7750108003044'],
      keywords: ['400g', 'gloria', 'lactosa', 'leche', 'sin'],
    ),
    ProductoStudioFoto(
      id: 'leche_chocolatada_gloria',
      nombre: 'Leche Chocolatada Gloria 1 Litro',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: '$_basePath/leche_chocolatada_gloria.png',
      codigosBarras: ['7750108003051'],
      keywords: ['chocolatada', 'gloria', 'leche', 'litro'],
    ),
    ProductoStudioFoto(
      id: 'agua_san_mateo',
      nombre: 'Agua San Mateo 600ml Sin Gas',
      marca: 'San Mateo',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/agua_san_mateo.png',
      codigosBarras: ['775117011953', '775435704798', '775386598917', '775544203715', '775620527268'],
      keywords: ['600ml', 'agua', 'gas', 'mateo', 'san', 'sin'],
    ),
    ProductoStudioFoto(
      id: 'mayonesa_alacena',
      nombre: 'Crema de Ají Tarí Alacena Doypack 400g',
      marca: 'Alacena',
      categoria: 'Abarrotes y Fideos',
      imagenUrl: '$_basePath/mayonesa_alacena.png',
      codigosBarras: ['7750109004140', '7750109004133'],
      keywords: ['400g', 'ají', 'alacena', 'crema', 'doypack', 'mayonesa', 'tarí'],
    ),
    ProductoStudioFoto(
      id: 'colgate_total12',
      nombre: 'Crema Dental Colgate Total 12 Limpieza 75ml',
      marca: 'Colgate',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/colgate_total12.png',
      codigosBarras: ['7750113008025'],
      keywords: ['75ml', 'colgate', 'crema', 'dental', 'limpieza', 'total'],
    ),
    ProductoStudioFoto(
      id: 'colgate_triple_accion',
      nombre: 'Crema Dental Colgate Triple Acción 75ml',
      marca: 'Colgate',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/colgate_triple_accion.png',
      codigosBarras: ['7750113008032'],
      keywords: ['75ml', 'acción', 'colgate', 'crema', 'dental', 'triple'],
    ),
    ProductoStudioFoto(
      id: 'jamonada_san_fernando',
      nombre: 'Jamonada de Pollo San Fernando 450g',
      marca: 'San Fernando',
      categoria: 'Embutidos y Fiambrería',
      imagenUrl: '$_basePath/jamonada_san_fernando.png',
      codigosBarras: ['7750107002023'],
      keywords: ['450g', 'fernando', 'jamonada', 'pollo', 'san'],
    ),
    ProductoStudioFoto(
      id: 'cepillo_colgate',
      nombre: 'Cepillo Dental Colgate Zig Zag Medio',
      marca: 'Colgate',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/cepillo_colgate.png',
      codigosBarras: ['7750113008049'],
      keywords: ['cepillo', 'colgate', 'dental', 'medio', 'zag', 'zig'],
    ),
    ProductoStudioFoto(
      id: 'pan_bimbo_blanco',
      nombre: 'Pan de Molde Blanco Bimbo Chico 400g',
      marca: 'Bimbo',
      categoria: 'Panadería y Desayuno',
      imagenUrl: '$_basePath/pan_bimbo_blanco.png',
      codigosBarras: ['7750116011018'],
      keywords: ['400g', 'bimbo', 'blanco', 'chico', 'molde', 'pan'],
    ),
    ProductoStudioFoto(
      id: 'pan_bimbo_integral',
      nombre: 'Pan de Molde Integral Bimbo 400g',
      marca: 'Bimbo',
      categoria: 'Panadería y Desayuno',
      imagenUrl: '$_basePath/pan_bimbo_integral.png',
      codigosBarras: ['7750116011025'],
      keywords: ['400g', 'bimbo', 'integral', 'molde', 'pan'],
    ),
    ProductoStudioFoto(
      id: 'cafe_nescafe',
      nombre: 'Café Soluble Nescafé Tradición Frasco 50g',
      marca: 'Nescafé',
      categoria: 'Panadería y Desayuno',
      imagenUrl: '$_basePath/cafe_nescafe.png',
      codigosBarras: ['7750116011049'],
      keywords: ['50g', 'café', 'frasco', 'nescafé', 'soluble', 'tradición'],
    ),
    ProductoStudioFoto(
      id: 'galleta_tentacion',
      nombre: 'Galleta Tentación Chocolate 70g',
      marca: 'Victoria',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/galleta_tentacion.png',
      codigosBarras: ['7750115010073'],
      keywords: ['70g', 'chocolate', 'galleta', 'tentación', 'victoria'],
    ),
    ProductoStudioFoto(
      id: 'inka_kola',
      nombre: 'Inca Kola 500ml',
      marca: 'Inca Kola',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/inka_kola.png',
      codigosBarras: ['7750106001010', '7750106001027', '7750106001034', '7750106000018'],
      keywords: ['500ml', 'inca', 'kola'],
    ),
    ProductoStudioFoto(
      id: 'coca_cola',
      nombre: 'Coca Cola 3 Litros',
      marca: 'Coca Cola',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/coca_cola.png',
      codigosBarras: ['7751234567890', '7750106002017', '7750106002024', '7750106000025'],
      keywords: ['500ml', 'coca', 'cola', 'litros'],
    ),
    ProductoStudioFoto(
      id: 'galleta_casino',
      nombre: 'Galleta Casino Fresa 68g',
      marca: 'Victoria',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/galleta_casino.png',
      codigosBarras: ['7750115010059'],
      keywords: ['68g', 'casino', 'fresa', 'galleta', 'victoria'],
    ),
    ProductoStudioFoto(
      id: 'galleta_oreo',
      nombre: 'Galleta Oreo Original Tubo 108g',
      marca: 'Oreo',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/galleta_oreo.png',
      codigosBarras: ['7750115010080'],
      keywords: ['108g', 'galleta', 'oreo', 'original', 'tubo'],
    ),
    ProductoStudioFoto(
      id: 'galleta_margarita',
      nombre: 'Galleta Margarita Clásica 80g',
      marca: 'Sayón',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/galleta_margarita.png',
      codigosBarras: ['7750115010066'],
      keywords: ['80g', 'clásica', 'galleta', 'margarita', 'sayón'],
    ),
    ProductoStudioFoto(
      id: 'halls_menta',
      nombre: 'Pastillas Halls Extra Fuerte Menta',
      marca: 'Halls',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/halls_menta.png',
      codigosBarras: ['7750115010097'],
      keywords: ['extra', 'fuerte', 'halls', 'menta', 'pastillas'],
    ),
    ProductoStudioFoto(
      id: 'caramelos_chicho',
      nombre: 'Caramelos Chicho Surtido Paquete 100g',
      marca: 'Chicho',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/caramelos_chicho.png',
      codigosBarras: ['7750115010103'],
      keywords: ['100g', 'caramelos', 'chicho', 'paquete', 'surtido'],
    ),
    ProductoStudioFoto(
      id: 'mermelada_gloria',
      nombre: 'Mermelada de Fresa Gloria Vaso 310g',
      marca: 'Gloria',
      categoria: 'Panadería y Desayuno',
      imagenUrl: '$_basePath/mermelada_gloria.png',
      codigosBarras: ['7750116011032'],
      keywords: ['310g', 'fresa', 'gloria', 'mermelada', 'vaso'],
    ),
    ProductoStudioFoto(
      id: 'avena_tres_ositos',
      nombre: 'Avena Precocida 3 Ositos Bolsa 250g',
      marca: '3 Ositos',
      categoria: 'Panadería y Desayuno',
      imagenUrl: '$_basePath/avena_tres_ositos.png',
      codigosBarras: ['7750116011056'],
      keywords: ['250g', 'avena', 'bolsa', 'ositos', 'precocida'],
    ),
    ProductoStudioFoto(
      id: 'te_herbi',
      nombre: 'Té Herbi Clásico Caja x25 bolsitas',
      marca: 'Herbi',
      categoria: 'Panadería y Desayuno',
      imagenUrl: '$_basePath/te_herbi.png',
      codigosBarras: ['7750116011063'],
      keywords: ['bolsitas', 'caja', 'clásico', 'herbi', 'x25'],
    ),
    ProductoStudioFoto(
      id: 'manzanilla_herbi',
      nombre: 'Manzanilla Herbi Caja x25 bolsitas',
      marca: 'Herbi',
      categoria: 'Panadería y Desayuno',
      imagenUrl: '$_basePath/manzanilla_herbi.png',
      codigosBarras: ['7750116011070'],
      keywords: ['bolsitas', 'caja', 'herbi', 'manzanilla', 'x25'],
    ),
    ProductoStudioFoto(
      id: 'azucar_paramonga',
      nombre: 'Azúcar Rubia Paramonga 1kg',
      marca: 'Paramonga',
      categoria: 'Abarrotes y Fideos',
      imagenUrl: '$_basePath/azucar_paramonga.png',
      codigosBarras: ['7750109004089'],
      keywords: ['1kg', 'azúcar', 'paramonga', 'rubia'],
    ),
    ProductoStudioFoto(
      id: 'piqueo_snax',
      nombre: 'Piqueo Snax Familiar 200g',
      marca: 'Frito-Lay',
      categoria: 'Snacks y Piqueos',
      imagenUrl: '$_basePath/piqueo_snax.png',
      codigosBarras: ['7750075001081'],
      keywords: ['200g', 'familiar', 'frito', 'lay', 'piqueo', 'snax'],
    ),
    ProductoStudioFoto(
      id: 'aceite_cocinero',
      nombre: 'Aceite Vegetal Cocinero 900ml',
      marca: 'Cocinero',
      categoria: 'Abarrotes y Fideos',
      imagenUrl: '$_basePath/aceite_cocinero.png',
      codigosBarras: ['7750109004072'],
      keywords: ['900ml', 'aceite', 'cocinero', 'vegetal'],
    ),
    ProductoStudioFoto(
      id: 'atun_fanny',
      nombre: 'Filete de Atún Fanny en Aceite 170g',
      marca: 'Fanny',
      categoria: 'Abarrotes y Fideos',
      imagenUrl: '$_basePath/atun_fanny.png',
      codigosBarras: ['7750109004119'],
      keywords: ['170g', 'aceite', 'atún', 'fanny', 'filete'],
    ),
    ProductoStudioFoto(
      id: 'helado_sin_parar',
      nombre: 'Helado Sin Parar Lúcuma Chispas',
      marca: 'D\'Onofrio',
      categoria: 'Helados y Postres',
      imagenUrl: '$_basePath/helado_sin_parar.png',
      codigosBarras: ['7750110005031'],
      keywords: ['chispas', 'helado', 'lúcuma', 'onofrio', 'parar', 'sin'],
    ),
    ProductoStudioFoto(
      id: 'helado_bombones',
      nombre: 'Helado Bombones D\'Onofrio Caja x8',
      marca: 'D\'Onofrio',
      categoria: 'Helados y Postres',
      imagenUrl: '$_basePath/helado_bombones.png',
      codigosBarras: ['7750110005079'],
      keywords: ['bombones', 'caja', 'helado', 'onofrio'],
    ),
    ProductoStudioFoto(
      id: 'ron_cartavio',
      nombre: 'Ron Cartavio Black 750ml',
      marca: 'Cartavio',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/ron_cartavio.png',
      codigosBarras: ['7750111006052'],
      keywords: ['750ml', 'black', 'cartavio', 'ron'],
    ),
    ProductoStudioFoto(
      id: 'vino_tabernero',
      nombre: 'Vino Tinto Tabernero Borgoña 750ml',
      marca: 'Tabernero',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/vino_tabernero.png',
      codigosBarras: ['7750111006076'],
      keywords: ['750ml', 'borgoña', 'tabernero', 'tinto', 'vino'],
    ),
    ProductoStudioFoto(
      id: 'helado_jet',
      nombre: 'Hamilton Rojo Clásico Cajetilla x20',
      marca: 'Hamilton',
      categoria: 'Cigarrillos y Tabacos',
      imagenUrl: '$_basePath/helado_jet.png',
      codigosBarras: ['7750112007028', '7750110005062', '7750112007011', '7750112007035', '7750112007042'],
      keywords: ['box', 'cajetilla', 'chocolate', 'click', 'clásico', 'doble', 'gold', 'hamilton', 'helado', 'jet', 'lucky', 'malboro', 'mall', 'menta', 'onofrio', 'pall', 'rojo', 'strike', 'x10', 'x20'],
    ),
    ProductoStudioFoto(
      id: 'encendedor_tokai',
      nombre: 'Encendedor Tokai Clásico Descartable',
      marca: 'Tokai',
      categoria: 'Cigarrillos y Tabacos',
      imagenUrl: '$_basePath/encendedor_tokai.png',
      codigosBarras: ['7750112007059'],
      keywords: ['clásico', 'descartable', 'encendedor', 'tokai'],
    ),
    ProductoStudioFoto(
      id: 'jabon_camay',
      nombre: 'Jabón de Tocador Camay Clásico 125g',
      marca: 'Camay',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/jabon_camay.png',
      codigosBarras: ['7750113008056'],
      keywords: ['125g', 'camay', 'clásico', 'jabón', 'tocador'],
    ),
    ProductoStudioFoto(
      id: 'shampoo_pantene',
      nombre: 'Shampoo Pantene Restauración 375ml',
      marca: 'Pantene',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/shampoo_pantene.png',
      codigosBarras: ['7750113008087', '7908132297479'],
      keywords: ['375ml', 'esyka', 'pantene', 'restauración', 'shampoo'],
    ),
    ProductoStudioFoto(
      id: 'crema_tari',
      nombre: 'Crema de Ají Tarí Alacena Doypack 400g',
      marca: 'Alacena',
      categoria: 'Abarrotes y Fideos',
      imagenUrl: '/crema_tari.png',
      codigosBarras: ['7750114009046'],
      keywords: ['400g', 'ají', 'aji', 'alacena', 'crema', 'doypack', 'picante', 'salsa', 'tari', 'tarí'],
    ),
    ProductoStudioFoto(
      id: 'fosforos_la_llama',
      nombre: 'Fósforos La Llama paquete x10 cajitas',
      marca: 'La Llama',
      categoria: 'Cigarrillos y Tabacos',
      imagenUrl: '/fosforos_la_llama.png',
      codigosBarras: ['7750114009053'],
      keywords: ['cajitas', 'fósforos', 'fosforos', 'la llama', 'llama', 'paquete', 'x10'],
    ),
    ProductoStudioFoto(
      id: 'suavizante_suavitel',
      nombre: 'Suavizante Suavitel Fresca Primavera 850ml',
      marca: 'Suavitel',
      categoria: 'Limpieza y Cuidado del Hogar',
      imagenUrl: '$_basePath/suavizante_suavitel.png',
      codigosBarras: ['7750114009084'],
      keywords: ['850ml', 'fresca', 'primavera', 'suavitel', 'suavizante'],
    ),
    ProductoStudioFoto(
      id: 'gel_antibacterial',
      nombre: 'Gel Antibacterial',
      marca: 'Genérico',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/gel_antibacterial.png',
      codigosBarras: ['7755236000632'],
      keywords: ['antibacterial', 'gel'],
    ),
    ProductoStudioFoto(
      id: 'fideos_spaghetti_don_vittorio',
      nombre: 'Fideos Don Vittorio Spaghetti 450g',
      marca: 'Don Vittorio',
      categoria: 'Abarrotes y Fideos',
      imagenUrl: '$_basePath/fideos_spaghetti_don_vittorio.png',
      codigosBarras: ['7750109004010'],
      keywords: ['450g', 'don', 'fideos', 'spaghetti', 'vittorio'],
    ),
    ProductoStudioFoto(
      id: 'fideos_codito_don_vittorio',
      nombre: 'Fideos Don Vittorio Codito 450g',
      marca: 'Don Vittorio',
      categoria: 'Abarrotes y Fideos',
      imagenUrl: '$_basePath/fideos_codito_don_vittorio.png',
      codigosBarras: ['7750109004034'],
      keywords: ['450g', 'codito', 'don', 'fideos', 'vittorio'],
    ),
    ProductoStudioFoto(
      id: 'lays_onduladas',
      nombre: 'Papas Lays Ondas Cebolla y Queso 150g',
      marca: 'Lays',
      categoria: 'Snacks y Piqueos',
      imagenUrl: '$_basePath/lays_onduladas.png',
      codigosBarras: ['7750075001012'],
      keywords: ['150g', 'cebolla', 'lays', 'ondas', 'papas', 'queso'],
    ),
    ProductoStudioFoto(
      id: 'arroz_costeno',
      nombre: 'Arroz Extra Costeño Bolsa 1kg',
      marca: 'Costeño',
      categoria: 'Abarrotes y Fideos',
      imagenUrl: '$_basePath/arroz_costeno.png',
      codigosBarras: ['7750109004041', '7750350000010'],
      keywords: ['1kg', 'arroz', 'bolsa', 'costeño', 'extra'],
    ),
    ProductoStudioFoto(
      id: 'yogur_gloria_fresa',
      nombre: 'Yogur Gloria Fresa 1 Litro',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: '$_basePath/yogur_gloria_fresa.png',
      codigosBarras: ['7750108003068'],
      keywords: ['fresa', 'gloria', 'litro', 'yogur'],
    ),
    ProductoStudioFoto(
      id: 'yogur_gloria_vainilla',
      nombre: 'Yogur Gloria Vainilla Francesa 1 Litro',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: '$_basePath/yogur_gloria_vainilla.png',
      codigosBarras: ['7750108003075'],
      keywords: ['francesa', 'gloria', 'litro', 'vainilla', 'yogur'],
    ),
    ProductoStudioFoto(
      id: 'mantequilla_laive',
      nombre: 'Mantequilla con Sal Laive Barra 200g',
      marca: 'Laive',
      categoria: 'Lácteos y Derivados',
      imagenUrl: '$_basePath/mantequilla_laive.png',
      codigosBarras: ['7750108003082'],
      keywords: ['200g', 'barra', 'con', 'laive', 'mantequilla', 'sal'],
    ),
    ProductoStudioFoto(
      id: 'margarina_manty',
      nombre: 'Margarina Manty Pote 225g',
      marca: 'Alicorp',
      categoria: 'Lácteos y Derivados',
      imagenUrl: '$_basePath/margarina_manty.png',
      codigosBarras: ['7750108003099'],
      keywords: ['225g', 'alicorp', 'manty', 'margarina', 'pote'],
    ),
    ProductoStudioFoto(
      id: 'leche_condensada_nestle',
      nombre: 'Leche Condensada Nestlé 393g',
      marca: 'Nestlé',
      categoria: 'Lácteos y Derivados',
      imagenUrl: '$_basePath/leche_condensada_nestle.png',
      codigosBarras: ['7750108003105'],
      keywords: ['393g', 'condensada', 'leche', 'nestlé'],
    ),
    ProductoStudioFoto(
      id: 'fideos_canuto_lavaggi',
      nombre: 'Fideos Lavaggi Canuto Corto 450g',
      marca: 'Lavaggi',
      categoria: 'Abarrotes y Fideos',
      imagenUrl: '$_basePath/fideos_canuto_lavaggi.png',
      codigosBarras: ['7750109004027'],
      keywords: ['450g', 'canuto', 'corto', 'fideos', 'lavaggi'],
    ),
    ProductoStudioFoto(
      id: 'arroz_faraon',
      nombre: 'Arroz Superior Faraón Bolsa 1kg',
      marca: 'Faraón',
      categoria: 'Abarrotes y Fideos',
      imagenUrl: '$_basePath/arroz_faraon.png',
      codigosBarras: ['7750109004058'],
      keywords: ['1kg', 'arroz', 'bolsa', 'faraón', 'superior'],
    ),
    ProductoStudioFoto(
      id: 'helado_peziduri_tricolor',
      nombre: 'Helado Peziduri Tricolor 1L',
      marca: 'D\'Onofrio',
      categoria: 'Helados y Postres',
      imagenUrl: '$_basePath/helado_peziduri_tricolor.png',
      codigosBarras: ['7750110005055'],
      keywords: ['helado', 'onofrio', 'peziduri', 'tricolor'],
    ),
    ProductoStudioFoto(
      id: 'cerveza_stella',
      nombre: 'Cerveza Stella Artois 330ml Botella',
      marca: 'Stella Artois',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/cerveza_stella.png',
      codigosBarras: ['7750111006045'],
      keywords: ['330ml', 'artois', 'botella', 'cerveza', 'stella'],
    ),
    ProductoStudioFoto(
      id: 'aceite_primor',
      nombre: 'Aceite Vegetal Primor Premium 900ml',
      marca: 'Primor',
      categoria: 'Abarrotes y Fideos',
      imagenUrl: '$_basePath/aceite_primor.png',
      codigosBarras: ['7750109004065', '7750109004102', '7750350000027'],
      keywords: ['170g', '900ml', 'aceite', 'atún', 'clásico', 'premium', 'primor', 'trozos', 'vegetal'],
    ),
    ProductoStudioFoto(
      id: 'cerveza_pilsen',
      nombre: 'Cerveza Pilsen Callao 650ml Retornable',
      marca: 'Backus',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/cerveza_pilsen.png',
      codigosBarras: ['7750111006021', '7750106007012'],
      keywords: ['355ml', '650ml', 'backus', 'callao', 'cerveza', 'lata', 'pilsen', 'retornable'],
    ),
    ProductoStudioFoto(
      id: 'cerveza_cristal',
      nombre: 'Cerveza Cristal 650ml Botella Retornable',
      marca: 'Backus',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/cerveza_cristal.png',
      codigosBarras: ['7750111006014'],
      keywords: ['650ml', 'backus', 'botella', 'cerveza', 'cristal', 'retornable'],
    ),
    ProductoStudioFoto(
      id: 'helado_sublime',
      nombre: 'Helado Sublime D\'Onofrio Paleta',
      marca: 'D\'Onofrio',
      categoria: 'Helados y Postres',
      imagenUrl: '$_basePath/helado_sublime.png',
      codigosBarras: ['7750110005017'],
      keywords: ['helado', 'onofrio', 'paleta', 'sublime'],
    ),
    ProductoStudioFoto(
      id: 'doritos_queso',
      nombre: 'Doritos Mega Queso 150g',
      marca: 'Frito-Lay',
      categoria: 'Snacks y Piqueos',
      imagenUrl: '$_basePath/doritos_queso.png',
      codigosBarras: ['7750075001029'],
      keywords: ['150g', 'doritos', 'frito', 'lay', 'mega', 'queso'],
    ),
    ProductoStudioFoto(
      id: 'chizitos_queso',
      nombre: 'Chizitos Fiesta Queso 160g',
      marca: 'Frito-Lay',
      categoria: 'Snacks y Piqueos',
      imagenUrl: '$_basePath/chizitos_queso.png',
      codigosBarras: ['7750075001036'],
      keywords: ['160g', 'chizitos', 'fiesta', 'frito', 'lay', 'queso'],
    ),
    ProductoStudioFoto(
      id: 'kolynos',
      nombre: 'Crema Dental Kolynos Triple Limpieza 120g',
      marca: 'Kolynos',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/kolynos.png',
      codigosBarras: ['7750113008018'],
      keywords: ['120g', 'crema', 'dental', 'kolynos', 'limpieza', 'triple'],
    ),
    ProductoStudioFoto(
      id: 'cuates_picantes',
      nombre: 'Cuates Picantes 150g',
      marca: 'Karinto',
      categoria: 'Snacks y Piqueos',
      imagenUrl: '$_basePath/cuates_picantes.png',
      codigosBarras: ['7750075001043'],
      keywords: ['150g', 'cuates', 'karinto', 'picantes'],
    ),
    ProductoStudioFoto(
      id: 'chifle_piurano',
      nombre: 'Chifle Piurano Salado 100g',
      marca: 'Karinto',
      categoria: 'Snacks y Piqueos',
      imagenUrl: '$_basePath/chifle_piurano.png',
      codigosBarras: ['7750075001050'],
      keywords: ['100g', 'chifle', 'karinto', 'piurano', 'salado'],
    ),
    ProductoStudioFoto(
      id: 'mani_karinto',
      nombre: 'Maní Salado Karinto 100g',
      marca: 'Karinto',
      categoria: 'Snacks y Piqueos',
      imagenUrl: '$_basePath/mani_karinto.png',
      codigosBarras: ['7750075001067'],
      keywords: ['100g', 'karinto', 'maní', 'salado'],
    ),
    ProductoStudioFoto(
      id: 'tortees_picantes',
      nombre: 'Tortees Picantes 140g',
      marca: 'Frito-Lay',
      categoria: 'Snacks y Piqueos',
      imagenUrl: '$_basePath/tortees_picantes.png',
      codigosBarras: ['7750075001074'],
      keywords: ['140g', 'frito', 'lay', 'picantes', 'tortees'],
    ),
    ProductoStudioFoto(
      id: 'cheese_tris',
      nombre: 'Cheese Tris 150g',
      marca: 'Frito-Lay',
      categoria: 'Snacks y Piqueos',
      imagenUrl: '$_basePath/cheese_tris.png',
      codigosBarras: ['7750075001098'],
      keywords: ['150g', 'cheese', 'frito', 'lay', 'tris'],
    ),
    ProductoStudioFoto(
      id: 'hot_dog_san_fernando',
      nombre: 'Hot Dog de Pollo San Fernando 500g',
      marca: 'San Fernando',
      categoria: 'Embutidos y Fiambrería',
      imagenUrl: '$_basePath/hot_dog_san_fernando.png',
      codigosBarras: ['7750107002016'],
      keywords: ['500g', 'dog', 'fernando', 'hot', 'pollo', 'san'],
    ),
    ProductoStudioFoto(
      id: 'sal_emsal',
      nombre: 'Sal Yodada Marina Emsal 1kg',
      marca: 'Emsal',
      categoria: 'Abarrotes y Fideos',
      imagenUrl: '$_basePath/sal_emsal.png',
      codigosBarras: ['7750109004096'],
      keywords: ['1kg', 'emsal', 'marina', 'sal', 'yodada'],
    ),
    ProductoStudioFoto(
      id: 'tuco_sibarita',
      nombre: 'Salsa de Tomate Tuco Sibarita 260g',
      marca: 'Sibarita',
      categoria: 'Abarrotes y Fideos',
      imagenUrl: '$_basePath/tuco_sibarita.png',
      codigosBarras: ['7750109004126'],
      keywords: ['260g', 'salsa', 'sibarita', 'tomate', 'tuco'],
    ),
    ProductoStudioFoto(
      id: 'helado_frio_rico',
      nombre: 'Helado Frío Rico Vainilla y Lúcuma',
      marca: 'D\'Onofrio',
      categoria: 'Helados y Postres',
      imagenUrl: '$_basePath/helado_frio_rico.png',
      codigosBarras: ['7750110005024'],
      keywords: ['frío', 'helado', 'lúcuma', 'onofrio', 'rico', 'vainilla'],
    ),
    ProductoStudioFoto(
      id: 'helado_peziduri_vainilla',
      nombre: 'Helado Peziduri Vainilla Chispas 1L',
      marca: 'D\'Onofrio',
      categoria: 'Helados y Postres',
      imagenUrl: '$_basePath/helado_peziduri_vainilla.png',
      codigosBarras: ['7750110005048'],
      keywords: ['chispas', 'helado', 'onofrio', 'peziduri', 'vainilla'],
    ),
    ProductoStudioFoto(
      id: 'helado_morochas',
      nombre: 'Helado Morochas D\'Onofrio',
      marca: 'D\'Onofrio',
      categoria: 'Helados y Postres',
      imagenUrl: '$_basePath/helado_morochas.png',
      codigosBarras: ['7750110005086'],
      keywords: ['helado', 'morochas', 'onofrio'],
    ),
    ProductoStudioFoto(
      id: 'cerveza_corona',
      nombre: 'Cerveza Corona Extra 355ml Botella',
      marca: 'Corona',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/cerveza_corona.png',
      codigosBarras: ['7750111006038'],
      keywords: ['355ml', 'botella', 'cerveza', 'corona', 'extra'],
    ),
    ProductoStudioFoto(
      id: 'pisco_queirolo',
      nombre: 'Pisco Queirolo Quebranta 750ml',
      marca: 'Santiago Queirolo',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/pisco_queirolo.png',
      codigosBarras: ['7750111006069'],
      keywords: ['750ml', 'pisco', 'quebranta', 'queirolo', 'santiago'],
    ),
    ProductoStudioFoto(
      id: 'whisky_johnnie_walker',
      nombre: 'Whisky Johnnie Walker Red Label 750ml',
      marca: 'Johnnie Walker',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/whisky_johnnie_walker.png',
      codigosBarras: ['7750111006083'],
      keywords: ['750ml', 'johnnie', 'label', 'red', 'walker', 'whisky'],
    ),
    ProductoStudioFoto(
      id: 'jabon_dove',
      nombre: 'Jabón de Tocador Dove Original 90g',
      marca: 'Dove',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/jabon_dove.png',
      codigosBarras: ['7750113008063'],
      keywords: ['90g', 'dove', 'jabón', 'original', 'tocador'],
    ),
    ProductoStudioFoto(
      id: 'shampoo_head_shoulders',
      nombre: 'Shampoo Head & Shoulders Limpieza 375ml',
      marca: 'Head & Shoulders',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/shampoo_head_shoulders.png',
      codigosBarras: ['7750113008070'],
      keywords: ['375ml', 'head', 'limpieza', 'shampoo', 'shoulders'],
    ),
    ProductoStudioFoto(
      id: 'rexona_men',
      nombre: 'Desodorante Rexona Men Aerosol 150ml',
      marca: 'Rexona',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/rexona_men.png',
      codigosBarras: ['7750113008094'],
      keywords: ['150ml', 'aerosol', 'desodorante', 'men', 'rexona'],
    ),
    ProductoStudioFoto(
      id: 'rexona_women',
      nombre: 'Desodorante Rexona Women Aerosol 150ml',
      marca: 'Rexona',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/rexona_women.png',
      codigosBarras: ['7750113008100'],
      keywords: ['150ml', 'aerosol', 'desodorante', 'rexona', 'women'],
    ),
    ProductoStudioFoto(
      id: 'lays_clasicas',
      nombre: 'Papas Lays Clásicas 160g',
      marca: 'Lays',
      categoria: 'Snacks y Piqueos',
      imagenUrl: '$_basePath/lays_clasicas.png',
      codigosBarras: ['7750106009999'],
      keywords: ['160g', 'clásicas', 'lays', 'papas'],
    ),
    ProductoStudioFoto(
      id: 'chocolate_sublime',
      nombre: 'Chocolate Sublime Clásico 30g',
      marca: 'Nestlé',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/chocolate_sublime.png',
      codigosBarras: ['7750115010011'],
      keywords: ['30g', 'chocolate', 'clásico', 'nestlé', 'sublime'],
    ),
    ProductoStudioFoto(
      id: 'chocolate_triangulo',
      nombre: 'Chocolate Triángulo D\'Onofrio 30g',
      marca: 'D\'Onofrio',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/chocolate_triangulo.png',
      codigosBarras: ['7750115010028'],
      keywords: ['30g', 'chocolate', 'onofrio', 'triángulo'],
    ),
    ProductoStudioFoto(
      id: 'galleta_cua_cua',
      nombre: 'Galleta Cua Cua Chocolate 18g',
      marca: 'Field',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/galleta_cua_cua.png',
      codigosBarras: ['7750115010035'],
      keywords: ['18g', 'chocolate', 'cua', 'field', 'galleta'],
    ),
    ProductoStudioFoto(
      id: 'galleta_dona_pepa',
      nombre: 'Galleta Doña Pepa 23g',
      marca: 'Field',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/galleta_dona_pepa.png',
      codigosBarras: ['7750115010042'],
      keywords: ['23g', 'doña', 'field', 'galleta', 'pepa'],
    ),
    ProductoStudioFoto(
      id: 'detergente_bolivar',
      nombre: 'Detergente Bolívar Blanco Activo 850g',
      marca: 'Bolívar',
      categoria: 'Limpieza y Cuidado del Hogar',
      imagenUrl: '$_basePath/detergente_bolivar.png',
      codigosBarras: ['7750114009015'],
      keywords: ['850g', 'activo', 'blanco', 'bolívar', 'detergente'],
    ),
    ProductoStudioFoto(
      id: 'cerveza_cusquena',
      nombre: 'Cerveza Cusqueña Trigo 310ml',
      marca: 'Cusqueña',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/cerveza_cusquena.png',
      codigosBarras: ['7750106006015'],
      keywords: ['310ml', 'cerveza', 'cusqueña', 'trigo'],
    ),
    ProductoStudioFoto(
      id: 'fanta',
      nombre: 'Fanta Naranja 500ml',
      marca: 'Fanta',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/fanta.png',
      codigosBarras: ['7750106008019'],
      keywords: ['500ml', 'fanta', 'naranja'],
    ),
    ProductoStudioFoto(
      id: 'guarana',
      nombre: 'Guaraná 3 Lt',
      marca: 'Backus',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/guarana.png',
      codigosBarras: ['7751507293994'],
      keywords: ['backus', 'guaraná'],
    ),
    ProductoStudioFoto(
      id: 'agua_san_luis',
      nombre: 'Agua San Luis 625ml Sin Gas',
      marca: 'San Luis',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/agua_san_luis.png',
      codigosBarras: ['7750106003014'],
      keywords: ['625ml', 'agua', 'gas', 'luis', 'san', 'sin'],
    ),
    ProductoStudioFoto(
      id: 'sporade',
      nombre: 'Sporade 500ml Tropical',
      marca: 'Sporade',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/sporade.png',
      codigosBarras: ['7750670010238'],
      keywords: ['500ml', 'sporade', 'tropical'],
    ),
    ProductoStudioFoto(
      id: 'cifrut',
      nombre: 'Cifrut 500ml Granadilla',
      marca: 'Cifrut',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/cifrut.png',
      codigosBarras: ['7750106005018'],
      keywords: ['500ml', 'cifrut', 'granadilla'],
    ),
    ProductoStudioFoto(
      id: 'red_bull',
      nombre: 'Red Bull Energy Drink 250ml',
      marca: 'Red Bull',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/red_bull.png',
      codigosBarras: ['9002490100070'],
      keywords: ['250ml', 'bull', 'drink', 'energy', 'red'],
    ),
    ProductoStudioFoto(
      id: 'papel_higienico_suave',
      nombre: 'Papel Higiénico Suave Rindemax x4 rollos',
      marca: 'Suave',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/papel_higienico_suave.png',
      codigosBarras: ['7750113008117'],
      keywords: ['higiénico', 'papel', 'rindemax', 'rollos', 'suave'],
    ),
    ProductoStudioFoto(
      id: 'toallas_nosotras',
      nombre: 'Toallas Higiénicas Nosotras x10',
      marca: 'Nosotras',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/toallas_nosotras.png',
      codigosBarras: ['7750113008124'],
      keywords: ['higiénicas', 'nosotras', 'toallas', 'x10'],
    ),
    ProductoStudioFoto(
      id: 'detergente_ace',
      nombre: 'Detergente Ace Limpieza Completa 750g',
      marca: 'Ace',
      categoria: 'Limpieza y Cuidado del Hogar',
      imagenUrl: '$_basePath/detergente_ace.png',
      codigosBarras: ['7750114009022'],
      keywords: ['750g', 'ace', 'completa', 'detergente', 'limpieza'],
    ),
    ProductoStudioFoto(
      id: 'detergente_opal',
      nombre: 'Detergente Opal Ultra 750g',
      marca: 'Opal',
      categoria: 'Limpieza y Cuidado del Hogar',
      imagenUrl: '$_basePath/detergente_opal.png',
      codigosBarras: ['7750114009039'],
      keywords: ['750g', 'detergente', 'opal', 'ultra'],
    ),
    ProductoStudioFoto(
      id: 'lejia_clorox',
      nombre: 'Lejía Clorox Tradicional 1 Litro',
      marca: 'Clorox',
      categoria: 'Limpieza y Cuidado del Hogar',
      imagenUrl: '$_basePath/lejia_clorox.png',
      codigosBarras: ['7750114009060'],
      keywords: ['clorox', 'lejía', 'litro', 'tradicional'],
    ),
    ProductoStudioFoto(
      id: 'limpiador_poett',
      nombre: 'Limpiador Multiusos Poett Lavanda 900ml',
      marca: 'Poett',
      categoria: 'Limpieza y Cuidado del Hogar',
      imagenUrl: '$_basePath/limpiador_poett.png',
      codigosBarras: ['7750114009077'],
      keywords: ['900ml', 'lavanda', 'limpiador', 'multiusos', 'poett'],
    ),
    ProductoStudioFoto(
      id: 'esponja_scotch',
      nombre: 'Esponja Verde Scotch Brite Clásica',
      marca: 'Scotch Brite',
      categoria: 'Limpieza y Cuidado del Hogar',
      imagenUrl: '$_basePath/esponja_scotch.png',
      codigosBarras: ['7750114009091'],
      keywords: ['brite', 'clásica', 'esponja', 'scotch', 'verde'],
    ),
    ProductoStudioFoto(
      id: 'bolsas_basura',
      nombre: 'Bolsas de Basura Negras Grande x10',
      marca: 'Sapolio',
      categoria: 'Limpieza y Cuidado del Hogar',
      imagenUrl: '$_basePath/bolsas_basura.png',
      codigosBarras: ['7750114009107'],
      keywords: ['basura', 'bolsas', 'grande', 'negras', 'sapolio', 'x10'],
    ),
    ProductoStudioFoto(
      id: 'hisopos_santoler',
      nombre: 'Hisopo',
      marca: 'Santoler',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/hisopos_santoler.png',
      codigosBarras: ['6977326450007'],
      keywords: ['hisopo', 'santoler'],
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

  static const Set<String> _stopwords = {
    'sin', 'con', 'del', 'las', 'los', 'por', 'para', 'pack', 'extra',
    'fuerte', 'clasico', 'original', 'unidad', 'sobre', 'botella', 'lata',
    'caja', 'bolsa', '1kg', '500g', '250g', '100g', '500ml', '650ml', '355ml',
    '310ml', '1l', '1.5l', '2l', '3l', '350g', '200g', '400g', '150g', '120g',
    '90g', '30g', '108g', 'x2', 'x3', 'x4', 'x6', 'x10', 'x12', 'x20', 'x24',
    'x30', 'x100', 'de', 'en', 'la', 'el', 'y'
  };

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

    // 2. Coincidencia inteligente ponderada por Nombre / Keywords
    if (nombre != null && nombre.trim().isNotEmpty) {
      final normNombre = _normalizar(nombre);
      if (normNombre.length >= 3) {
        final tokens = normNombre
            .split(RegExp(r'[^a-zA-Z0-9]+'))
            .where((t) => t.isNotEmpty && !_stopwords.contains(t))
            .toSet();

        ProductoStudioFoto? mejorItem;
        int mejorScore = 0;

        for (final item in _catalogoMaestro) {
          int score = 0;
          final normItemNombre = _normalizar(item.nombre);
          final normMarca = _normalizar(item.marca);

          if (normMarca.length >= 3 && !_stopwords.contains(normMarca) && normNombre.contains(normMarca)) {
            score += 3;
          }
          if (normNombre.contains(normItemNombre) || (normNombre.length >= 6 && normItemNombre.contains(normNombre))) {
            score += 5;
          }

          for (final kw in item.keywords) {
            final normKw = _normalizar(kw);
            if (_stopwords.contains(normKw) || normKw.length < 2) continue;
            if (tokens.contains(normKw)) {
              score += 2;
            } else if (normKw.length >= 4 && normNombre.contains(normKw)) {
              score += 1;
            }
          }

          if (score > mejorScore) {
            mejorScore = score;
            mejorItem = item;
          }
        }

        if (mejorScore >= 4) {
          return mejorItem;
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
